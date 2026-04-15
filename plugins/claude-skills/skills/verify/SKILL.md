---
name: verify
description: This skill should be used when the user asks to "verify", "verify this", "verify the code", "review", "review this", "review the code", "review stream", "check the code", "look over this", "audit this", or mentions reviewing files, checking against acceptance criteria, or validating a stream's work before marking it complete.
version: 2.1.0
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(cargo *), Bash(npm *), Bash(npx *), Bash(bash *)
---

# Verify

Reviews code written this session against the stream's plan, acceptance criteria, standards, and edge conditions. Presents findings interactively for triage — fix, defer, or skip each issue.

---

## Step 1: Gather Context

The meta branch lives in the **dedicated meta repo** (separate from the work repo where code was written). Read planning files from the meta repo:

```bash
git -C <meta-repo-path> show meta/<project-slug>:streams/<stream-name>/plan.md
git -C <meta-repo-path> show meta/<project-slug>:design.md 2>/dev/null || true
```

Find `<stream-name>` from the current branch name (e.g. `stream/<stream-name>`). Resolve `<meta-repo-path>` from `~/.claude/projects-registry.json` by matching the project slug. If no stream context, ask the user: "What are the acceptance criteria or goals I should review against?"

From `design.md`, extract the guiding principles (GP-1 through GP-N). From the stream's `plan.md`, extract the principle compliance table and quality checklist.

Read the diff from the work repo (current directory):

```bash
git diff main..HEAD --name-only
```

Read every source file touched or created this session, plus corresponding test files.

---

## Step 2: Review Dimensions

For each file in the diff, evaluate across all five dimensions:

### 2a. Acceptance Criteria Compliance

Map each AC item from the plan directly to the code. For each:
- Is it implemented? If not, is the gap intentional (deferred) or an omission?
- Is it implemented correctly, or is there a subtle mismatch between intent and code?

### 2b. Task List Completion

Go through the `## Tasks` checklist in the plan. For each task:
- Implemented in full, partially, or missing?
- Call out partials explicitly — a field that exists with no builder is partial, not complete.

### 2c. Correctness and Edge Cases

Look for:
- Silent failure modes (unwrap_or_default on data that came from the DB, etc.)
- Contract violations not enforced at the API boundary (doc says "must be X" but code doesn't assert it)
- Caller-supplied parameters that duplicate or can contradict DB state
- Functions that can't distinguish "not found" from "already done"
- Queries missing a scope filter that will break in a multi-tenant / multi-project scenario
- Async race conditions or missing await
- Off-by-one errors in pagination or index math

### 2d. Standards

- Positional column indices in row mappers — fragile if SELECT order changes
- Inconsistent error propagation (some paths propagate, others swallow)
- Public API surface: are the right things public? Are internals leaking?
- Test helper duplication across modules (same `setup()` written N times)

### 2e. Test Coverage Quality

For every test file in the diff:

- **Positive cases** — does each meaningful behavior have at least one test that asserts it works correctly?
- **Negative cases** — does each meaningful behavior have at least one test for a failure or invalid-input path (bad input, not-found, permission denied, error propagation)?
- **Trivial tests** — flag any test whose assertion would pass regardless of the feature's logic (e.g., `expect(service).toBeDefined()`, `expect(result).not.toBeNull()` with no meaningful setup, testing a constructor or framework wiring). These add noise and false confidence.
- **Duplicate paths** — flag any two tests that exercise the exact same code path through the function under test. Different inputs that hit the same branch provide no additional signal; keep the one that best documents the invariant.

### 2f. Reading Comprehension

- Does the doc comment accurately describe what the function does?
- Does the function name match its behavior?
- Are comments that explain *why* present where the code is non-obvious?
- Are there misleading comments (e.g. "idempotent-safe" on something that can't distinguish not-found from already-done)?

### 2g. Guiding Principle Compliance

If `design.md` exists with guiding principles, check each applicable GP against the code:

- For each GP in the stream plan's compliance table: does the code follow the stated approach?
- Are there any violations in the "Risk Areas" the plan identified?
- Are there principle violations the plan didn't anticipate?
- If the stream plan has a quality checklist, verify each item

Skip this dimension if no `design.md` or guiding principles exist.

---

## Step 3: Classify Findings

Collect all findings. Classify each by severity:

- **Critical** — data loss, silent corruption, or AC violated in a way that would fail a demo
- **Design** — structural issues that will cause pain when the next stream builds on this
- **Minor** — style, robustness, test coverage gaps
- **AC gaps** — plan tasks partially implemented or deferred (call out which)

---

## Step 4: Interactive Triage

Present findings **one at a time** — Critical first, then Design, then Minor, then AC gaps.

For each issue, show:

```
[N/Total] <Severity> — <short title>
<file:line if applicable>

<2-4 sentence description of the problem and why it matters>

Fix now / Defer / Skip?
```

Wait for the user to respond before moving to the next issue. Accept shorthand:
- `f` or `fix` → fix it immediately, then continue to the next issue
- `d` or `defer` → note it as deferred, continue
- `s` or `skip` → drop it, continue
- `?` → explain the issue in more depth before deciding

When the user chooses **fix**, make the change, show a brief diff or description of what changed, confirm it compiles/tests pass if applicable, then move on.

---

## Step 5: Summary

After all issues are triaged, print a final summary table:

| # | Title | Severity | Disposition |
|---|-------|----------|-------------|
| 1 | ...   | Critical | Fixed       |
| 2 | ...   | Design   | Deferred    |

End with one sentence: overall confidence in the stream output and any remaining risk.

---

## Important Notes

- Do not rewrite code during the review analysis — only report findings. Fix only when the user says `f`/`fix`.
- If the user says "fix all" or "fix everything", proceed through fixes in severity order, confirming each change briefly.
- Tests should live alongside source files (e.g. `src/types/Entry.test.ts`).
- If there are no findings, say so — don't manufacture issues.
