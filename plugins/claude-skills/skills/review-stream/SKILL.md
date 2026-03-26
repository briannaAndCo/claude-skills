---
name: review-stream
description: This skill should be used when the user asks to "review stream", "review code", "review PR", "check stream quality", "is this ready to merge", or wants an adversarial quality review of a stream's work. Runs parallel critic agents (AC verification, code quality, correctness) that can only read — never edit. Produces a scored review with actionable findings.
version: 1.0.0
---

# Review Stream

Adversarial review of a stream's implementation using the **worker-critic separation** pattern: **critics can never edit files; creators can never score themselves.**

Reviews run in isolated subagents with read-only tools. Each reviewer focuses on a different quality dimension and produces a confidence score. Findings are triaged interactively.

---

## Core Principle

> The reviewer never wrote the code it reviews. Each review stage runs in its own agent process with its own context window.

This prevents self-validation bias — the agent that implemented cannot also judge its own work.

---

## Flow

### 1. Resolve the Stream

Determine the project and stream to review. Prefer `project.json` for structured lookup:

```bash
git -C <repo-path> show <meta-branch>:project.json 2>/dev/null
```

Read the stream's plan from meta for AC reference:

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/plan.md
```

If the stream has a worktree, identify it:

```bash
ls <repo-path>/.worktrees/<stream> 2>/dev/null
```

If the stream has a feature branch, identify the diff:

```bash
git -C <repo-path> diff main...stream/<stream> --stat
git -C <repo-path> diff main...stream/<stream>
```

### 2. Launch Parallel Review Agents

Spawn **3 critic subagents** in parallel using the Agent tool. Each has **read-only tools only** — no Edit, Write, or destructive Bash.

#### Agent 1: AC Verification Critic

```
You are an acceptance criteria verification reviewer.

**Tools available:** Read, Glob, Grep, Bash (read-only commands only)
**Model:** sonnet

**Your task:**
Review the stream's implementation against its acceptance criteria.

Stream plan (with AC):
<stream plan content>

Changed files:
<diff --stat output>

For each acceptance criterion:
1. Check if it is fully implemented
2. Check if it has test coverage
3. Rate confidence 0-100

Output format:
## AC Verification
| Criterion | Status | Confidence | Evidence |
|-----------|--------|------------|----------|
| ... | PASS/FAIL/PARTIAL | 0-100 | file:line reference |

**Overall AC Score:** <0-100>
**Blocking issues:** <list or "none">
```

#### Agent 2: Code Quality Critic

```
You are a code quality reviewer. You focus on maintainability, conventions, and design.

**Tools available:** Read, Glob, Grep, Bash (read-only commands only)
**Model:** sonnet

**Your task:**
Review the changed files for code quality issues.

Changed files:
<diff --stat output>

Review checklist:
1. **Simplicity** — Is the code the simplest solution? Over-engineered?
2. **Conventions** — Does it follow codebase patterns? Naming, structure, imports?
3. **Scope discipline** — Does it only change what the stream requires? Any scope creep?
4. **Error handling** — Are errors handled at system boundaries? Not over-handled internally?
5. **Edge cases** — Are boundary conditions covered?
6. **Testability** — Can each component be tested in isolation?

For each issue found:
- Severity: CRITICAL (must fix) | WARNING (should fix) | SUGGESTION (consider)
- File and line reference
- What's wrong and how to fix it

Output format:
## Code Quality
| # | Severity | File:Line | Issue | Recommendation |
|---|----------|-----------|-------|----------------|
| 1 | CRITICAL | ... | ... | ... |

**Overall Quality Score:** <0-100>
**Blocking issues:** <list or "none">
```

#### Agent 3: Correctness Critic

```
You are a correctness reviewer. You focus on bugs, logic errors, and security.

**Tools available:** Read, Glob, Grep, Bash (read-only commands only)
**Model:** opus

**Your task:**
Review the changed files for correctness issues.

Changed files:
<diff output>

Review checklist:
1. **Logic errors** — Off-by-one, wrong conditions, missing cases
2. **State management** — Race conditions, stale state, inconsistent updates
3. **Security** — Input validation, injection, auth checks, secrets exposure
4. **Data flow** — Does data flow correctly across function/file boundaries?
5. **Regressions** — Could this change break existing behavior?
6. **Null/undefined** — Missing null checks, optional chaining gaps

For each issue found:
- Severity: CRITICAL | WARNING | SUGGESTION
- File and line reference
- Specific bug/vulnerability description
- Reproduction scenario if applicable

Output format:
## Correctness
| # | Severity | File:Line | Issue | Impact |
|---|----------|-----------|-------|--------|
| 1 | CRITICAL | ... | ... | ... |

**Overall Correctness Score:** <0-100>
**Blocking issues:** <list or "none">
```

### 3. Compile Results

Once all 3 agents return, compile their findings into a unified review:

```markdown
# Stream Review: <stream-name>

## Scores
| Dimension | Score | Blocking Issues |
|-----------|-------|----------------|
| AC Verification | 85 | none |
| Code Quality | 72 | 2 |
| Correctness | 90 | none |
| **Overall** | **82** | **2** |

## Blocking Issues (must fix before merge)
1. [QUALITY] src/api/auth.ts:45 — Missing input validation on user registration endpoint
2. [QUALITY] src/db/migrations/003.ts:12 — Migration not wrapped in transaction

## Warnings (should fix)
3. [CORRECTNESS] src/utils/cache.ts:78 — Cache TTL hardcoded, should use config
...

## Suggestions (consider)
5. [QUALITY] src/components/Form.tsx:23 — Could extract validation logic into hook
...
```

### 4. Quality Gate

**Scoring:**
- Each dimension: 0-100
- Overall = weighted average: AC (40%) + Quality (30%) + Correctness (30%)
- **80+ = ready to merge** (with any warnings addressed)
- **60-79 = needs work** (fix blocking issues, re-review)
- **<60 = significant rework needed**

### 5. Interactive Triage

Present each finding to the user and ask:
- **fix** — address this issue now
- **defer** — create a follow-up task
- **skip** — disagree with the finding (with reason)

For "fix" items, the user returns to the stream's worktree to make changes. After fixes, offer to re-run the review (or just the affected dimensions).

For "defer" items, note them in the stream's plan.md under a `## Deferred` section.

### 6. Update Stream Status

If the review passes (overall ≥80 with no unresolved blocking issues):
- Update stream status to `complete` in plan.md and project.json
- Offer to create a PR (delegate to create-pr if available)

If the review does not pass:
- Keep stream status as `in-progress`
- Summarize what needs fixing

---

## Guiding Principle Compliance Check

If the project has a `design.md` with guiding principles, add a 4th review dimension:

#### Agent 4: Principle Compliance Critic

Reviews implementation against each guiding principle (GP-1, GP-2, etc.) from `design.md`. Checks for violations, documents compliance evidence. Same read-only constraint.

This agent only runs if `design.md` exists on the meta branch.

---

## Model Selection for Review Agents

| Agent | Recommended Model | Why |
|-------|------------------|-----|
| AC Verification | Sonnet | Checklist comparison — structured, not deeply analytical |
| Code Quality | Sonnet | Pattern matching against conventions |
| Correctness | Opus | Needs deep reasoning about logic, state, security |
| Principle Compliance | Opus | Needs architectural judgment |

---

## Important Notes

- **Critics NEVER have Edit or Write tools.** They can only Read, Glob, Grep, and run read-only Bash commands. This is the core safety constraint.
- **The implementing agent NEVER scores its own work.** If the user asks "is my code ready?" from within a stream, launch review agents — don't self-evaluate.
- **Review against the plan, not against assumptions.** The stream's plan.md and AC are the contract. If the implementation does something the plan doesn't specify, that's scope creep, not a feature.
- **Use Read tool for files, Bash for git commands.** Only use Bash for git diff, git log, and read-only operations.
- **Re-review is cheap.** After fixes, re-run only the dimensions that had blocking issues. Don't re-run passing dimensions unless the fixes were cross-cutting.
- **Findings must cite specific files and lines.** No vague "the error handling could be better" — always `src/api/auth.ts:45`.
