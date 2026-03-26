---
name: review
description: This skill should be used when the user asks to "review", "review this", "review the code", "review stream", "check the code", "look over this", "audit this", or mentions reviewing files, checking against acceptance criteria, or validating a stream's work before marking it complete.
version: 2.0.0
---

# Review

Reviews code written this session against the stream's plan, acceptance criteria, standards, and edge conditions. Presents findings interactively for triage — fix, defer, or skip each issue.

---

## Step 1: Gather Context

Read the stream plan from the meta branch:

```bash
git show meta/<project-slug>:streams/<stream-name>/plan.md
```

Find `<stream-name>` from the current branch name (e.g. `stream/<stream-name>`). If no stream context, ask the user: "What are the acceptance criteria or goals I should review against?"

Also read:

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

### 2e. Reading Comprehension

- Does the doc comment accurately describe what the function does?
- Does the function name match its behavior?
- Are comments that explain *why* present where the code is non-obvious?
- Are there misleading comments (e.g. "idempotent-safe" on something that can't distinguish not-found from already-done)?

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
