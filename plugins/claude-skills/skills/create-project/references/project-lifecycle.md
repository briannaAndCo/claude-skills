# Project Lifecycle

The full lifecycle from idea to merged code, broken into phases. Each phase is a skill or sub-skill invocation.

## Tool Usage

Throughout all phases, prefer dedicated tools over Bash:

- **Read tool**: read files from disk or from git (via `git show meta/<project-slug>:<file>` in Bash only when on a different branch)
- **Write tool**: create new files
- **Edit tool**: modify existing files
- **Glob tool**: find files by pattern
- **Grep tool**: search file contents
- **Agent tool**: delegate parallel exploration, review, or research tasks to subagents
- **Bash tool**: only for git commands, directory creation, and `gh` CLI operations

---

## Phase Overview

```
1. CREATE        → git init, meta/<slug> branch, registry
2. REQUIREMENTS  → gather, discuss, define edge cases, write requirements.md
3. DESIGN        → high-level architecture, language-specific refinement, tradeoff review
4. DECOMPOSE     → break into streams with AC, dependencies, wave plan
5. STREAM DESIGN → codebase exploration, clarifying questions, refined AC, user approval
6. IMPLEMENT     → worktree per stream, plan mode, code
7. REVIEW        → AC verification, iterate, user-approved draft PR
8. MERGE         → merge to main, cleanup worktree, update meta
```

---

## Phase 1: Create (skill: `create-project`)

Already defined in SKILL.md. Creates repo, orphan `meta/<project-slug>` branch, registry entry.

**Output on meta branch:** `plan.md`, `session.md`, `tasks.md`

---

## Phase 2: Requirements (skill: `project-requirements`)

### Purpose
Turn source documents, typed context, and codebase exploration into a structured, testable requirements document with EARS syntax, terminology glossary, and decision log.

**See `skills/project-requirements/SKILL.md` for the full flow.**

### Summary

1. **Gather source material** — documents (file paths), typed input, or both. Optionally explore existing codebase.
2. **Analyze** — two phases:
   - Phase 1: Extract problem, actors, capabilities, constraints, terminology (confirm with user)
   - Phase 2: Three parallel agents — Gap Analyst, Conflict & Ambiguity Detector, Edge Case & Risk Scanner
3. **Surface questions** — one at a time: conflicts, critical gaps, ambiguous terms, naming, scope, edge cases, non-functional requirements
4. **Define capabilities** — structured with EARS syntax (event-driven, state-driven, ubiquitous, optional, unwanted behavior), AC, edge cases, not-included (one at a time)
5. **Establish terminology** — glossary with canonical names, definitions, aliases (one at a time)
6. **Adversarial self-review** — critical review agent checks testability, circular deps, completeness
7. **Compile and review** — section by section with user (one at a time)
8. **Commit** — `requirements.md` to meta

### Output: `requirements.md`

Contains: Problem Statement, Actors, Constraints, Capabilities (CAP-1..N with EARS requirements, AC, edge cases), Non-Requirements, Terminology glossary, Decision Log, Source Material list, Open Questions.

---

## Phase 3: Design (skill: `project-plan`)

### Purpose
Produce a high-level design with architecture, use cases, workflows, enforceable guiding principles, and mandatory stack guidelines. The guiding principles become the contract that all stream plans and reviews verify against.

**See `skills/project-plan/SKILL.md` for the full flow.**

### Summary

1. **Read context** — requirements from meta, existing codebase (architecture, docs, conventions)
2. **Use cases & workflows** — actors, interactions, end-to-end flows, boundaries (one question at a time)
3. **Architecture** — components, boundaries, data model, data flow, API surface (one component at a time)
4. **Guiding principles** — language-agnostic, enforceable rules with ID, statement, rationale, verification (one principle at a time)
5. **Stack guidelines** — always performed; discover existing conventions, surface discrepancies between docs and code, research stack best practices, define stack-specific guidelines mapped to guiding principles
6. **Technical decisions** — remaining tradeoffs (one at a time)
7. **Commit** — `design.md` to meta

### Output: `design.md`

Contains: Use Cases, Architecture, Guiding Principles (GP-1..N), Stack Guidelines (SG-1..N), Technical Decisions, Risks.

---

## Phase 4: Decompose (skill: `project-decompose`)

### Purpose
Break the design into implementable streams with high-level acceptance criteria, dependencies, and a wave plan.

### Flow

1. **Read context** — Use Bash to read from meta:
   ```bash
   git show meta/<project-slug>:requirements.md
   git show meta/<project-slug>:design.md
   git show meta/<project-slug>:plan.md
   ```

2. **Identify streams** — Map capabilities and components to streams:
   - Each stream should be independently implementable and reviewable
   - Each stream should take no more than a few sessions to complete
   - Prefer vertical slices (end-to-end through a feature) over horizontal layers

3. **Define high-level AC per stream** — For each stream:
   - Pull relevant acceptance criteria from requirements (high-level, behavioral)
   - Brief description of what "done" means
   - Do NOT go into implementation detail here — that happens in the stream design pass (Phase 5)

4. **Map dependencies** — Identify which streams block others:
   - Direct: stream B needs stream A's code/types/schema
   - Data: stream B needs stream A's migrations or seed data
   - API: stream B calls endpoints/functions defined in stream A

5. **Wave plan** — Group streams into waves:
   - Wave 1: streams with no blockers
   - Wave N: streams whose blockers are all in earlier waves
   - Within a wave, all streams are independent and can run in parallel

6. **Review with user** — Present the decomposition:
   - Stream list with AC summaries
   - Dependency graph
   - Wave plan
   - Ask: "Does this grouping make sense? Should any streams be split or merged?"

7. **Commit** — Use the **Edit tool** to update `plan.md` and the **Write tool** to create each `streams/<name>/plan.md`. Then commit to meta:
   ```bash
   cd <repo-path>
   git checkout meta/<project-slug>
   git add plan.md streams/
   git commit -m "meta: decompose into streams with wave plan"
   git checkout <original-branch>
   ```

### Updated `plan.md` Format (after decomposition)

```markdown
# Plan: <project-name>

## Objective
<from create phase>

## Streams

| Stream | Status | Blocked By | Notes |
|--------|--------|------------|-------|
| stream-a | unblocked | — | Brief description |
| stream-b | blocked | stream-a | Brief description |
| stream-c | blocked | stream-a | Brief description |
| stream-d | blocked | stream-b, stream-c | Brief description |

## Wave Plan

### Wave 1
- stream-a

### Wave 2 (after Wave 1 merges)
- stream-b
- stream-c

### Wave 3 (after Wave 2 merges)
- stream-d

## Requirements Mapping

| Capability | Stream(s) |
|-----------|-----------|
| Capability 1 | stream-a, stream-b |
| Capability 2 | stream-c |
```

### Stream `plan.md` Format (after decomposition — high-level)

```markdown
# Plan: <stream-name>

## Objective
<what this stream delivers>

## Acceptance Criteria
- [ ] <high-level behavioral criterion>
- [ ] <high-level behavioral criterion>

## Dependencies
- Blocked by: <stream-names or "none">
- Blocks: <stream-names or "none">

## Notes
```

---

## Phase 5: Stream Design (skill: `stream-plan`)

### Purpose
Design a stream at implementation level with guiding principle compliance, front-loaded quality checks, and best practices. Get user approval before any code is written. All questions are asked one at a time.

**See `skills/stream-plan/SKILL.md` for the full flow.**

### Summary

1. **Read context** — design.md (guiding principles, stack guidelines), requirements.md, stream's plan.md from meta. Verify stream is unblocked.
2. **Parallel discovery** — 3 agents (modeled after review-stream's 3-agent pattern):
   - Codebase Explorer: patterns, integration points, existing GP implementations
   - Principle Compliance Planner: which GPs apply, how to satisfy each, risk areas
   - Best Practices Researcher: domain-specific practices filtered through guiding principles
3. **Surface questions** — one at a time: principle conflicts, scope, integration, errors, edge cases, performance, backward compatibility
4. **Architecture & approach** — files, patterns, data flow, integration (options one at a time)
5. **Quality checklist** — front-loads review concerns: simplicity, conventions, scope, errors, edge cases, tests (one category at a time)
6. **Refine AC** — implementation-level criteria including GP compliance
7. **Task breakdown** — commit-sized tasks with GP/quality annotations
8. **Review plan with user** — section by section, explicit approval on each
9. **Commit** — refined stream plan.md to meta

### Output: Refined `streams/<name>/plan.md`

Contains: Objective, Approach, Principle Compliance table, Stack Guidelines Applied, Quality Checklist, Acceptance Criteria, Tasks, Files, Dependencies, Decisions, Notes.

---

## Phase 6: Implement (skill: `open-stream`, step 2)

### Purpose
Open the stream for implementation in an isolated worktree after the design pass is approved.

### Worktree Convention

All worktrees live in a standardized location relative to the repo:

```
<repo-root>/.worktrees/<stream-name>/
```

Use **Grep tool** to check if `.worktrees` is already in `.gitignore`. If not, use the **Edit tool** to add it.

### Flow

#### Step 1: Create Worktree

```bash
cd <repo-root>
git worktree add .worktrees/<stream-name> -b stream/<stream-name> main
```

#### Step 2: Generate CLAUDE.md

Use the **Write tool** to create `<worktree-root>/CLAUDE.md`, dynamically built from current meta state:

```markdown
# Stream: <stream-name>

## Project
<project name and objective from plan.md>

## This Stream
<objective, approach, and refined AC from streams/<name>/plan.md>

## Task Plan
<ordered task list from stream plan>

## Context
- Worktree: <repo>/.worktrees/<stream-name>/
- Branch: stream/<stream-name>
- Base: main
- Key files: <list from design pass>

## Instructions
- Work only within this worktree
- Commit on branch stream/<stream-name>
- Do not modify files outside this stream's scope
- Follow codebase conventions identified in the design pass
- When done, mark all AC as checked in streams/<name>/plan.md on meta
```

#### Step 3: Update Meta

Use the **Edit tool** to set stream status to `in-progress` in `plan.md` on meta branch, then commit:

```bash
cd <repo-path>
git checkout meta/<project-slug>
git add plan.md
git commit -m "meta: stream in-progress — <stream-name>"
git checkout <original-branch>
```

#### Step 4: Launch

Open Claude session in the worktree directory (via terminal tab or tmux window).

### Implementation Guidelines

- Start in plan mode (`--permission-mode plan`)
- Keep implementation to 30-minute blocks aligned with task plan
- Commit frequently on the stream branch — one commit per task when practical
- When all AC are met, signal readiness for review

---

## Phase 7: Review (skill: `review-stream`)

### Purpose
Review the stream's work against its AC, iterate until passing, then create a draft PR with user approval.

### Flow

#### Step 1: Review Against AC

Launch 3 **review agents** in parallel, each focused on a different aspect:

1. **AC verification agent** — For each acceptance criterion in the stream's `plan.md`:
   - Read the relevant code using Read/Grep/Glob tools
   - Verify the criterion is met
   - Return pass/fail with evidence (file paths, line numbers)

2. **Quality agent** — Check for:
   - Simplicity, DRY, elegance
   - Codebase convention compliance
   - No unnecessary complexity or scope creep

3. **Correctness agent** — Check for:
   - Bugs and edge case handling
   - Error handling completeness
   - Integration correctness with existing code

Consolidate findings. Present issues **one at a time** to the user (highest severity first). For each issue, include:
- What the issue is
- Where it is (file:line)
- Suggested fix
- Confidence level (skip anything below 80%)

#### Step 2: Iterate

If changes needed:
- Make fixes in the worktree using **Edit tool**
- Commit on the stream branch
- Re-run review agents on changed files until all AC pass

#### Step 3: Request Approval to Create PR

When all AC pass, present a summary:
- List of commits on the stream branch (`git log main..stream/<stream-name> --oneline`)
- AC checklist (all checked)
- Any notes or caveats
- Ask: "Ready to create a draft PR?"
- **Do not create a PR until the user explicitly approves.**

#### Step 4: Create Draft PR (only after user approval)

```bash
cd <worktree>
git push -u origin stream/<stream-name>
```

Use Bash to create the PR with `gh`:

```bash
gh pr create --draft \
  --title "<stream-name>: <brief description>" \
  --body "<AC checklist from stream plan.md>"
```

#### Step 5: Mark Ready

Only when the user explicitly requests it:

```bash
gh pr ready
```

---

## Phase 8: Merge (skill: `merge-stream`)

### Purpose
Merge the stream's PR, clean up, and update project state.

### Flow

#### Step 1: Merge PR

```bash
gh pr merge --squash
```

#### Step 2: Clean Up Worktree

```bash
cd <repo-root>
git worktree remove .worktrees/<stream-name>
git branch -d stream/<stream-name>
```

#### Step 3: Update Meta

Use the **Edit tool** on `plan.md` (on meta branch) to:
- Set stream status to `complete`
- Check if any blocked streams are now unblocked (all their blockers are `complete`)
- Update those streams to `unblocked`

Then commit:

```bash
cd <repo-path>
git checkout meta/<project-slug>
git add plan.md
git commit -m "meta: stream complete — <stream-name>"
git checkout <original-branch>
```

#### Step 4: Notify

Tell the user:
- Which stream was merged
- Which streams are now unblocked
- What the next wave looks like

#### Step 5: Rebase Remaining Worktrees

Use Bash to list active worktrees: `git worktree list`. For any active stream worktrees:

```bash
cd <worktree>
git rebase main
```

Warn the user if conflicts arise — do not force-resolve.
