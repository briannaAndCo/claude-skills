---
name: review
description: This skill should be used when the user asks to "review", "review this", "review the code", "review stream", "check the code", "look over this", "audit this", or mentions reviewing files, checking against acceptance criteria, or validating a stream's work before marking it complete.
version: 1.0.0
---

# Review

Reviews code against the active stream's acceptance criteria, best practices, and edge conditions. Ensures all files have tests covering main functionality.

---

## Step 1: Gather Context

If inside a stream (stream directory is known), read:

```bash
cat <stream-plan-path>/plan.md
```

Extract:
- **Acceptance Criteria** (the AC checklist)
- **Objective** (what this stream is supposed to do)

If the stream is a sub-stream, also read the parent stream's `plan.md` for broader context.

If no stream context is available, ask the user: "What are the acceptance criteria or goals I should review against?"

---

## Step 2: Discover Files

Find all source files in scope:

```bash
find <repo-path>/src -type f -name "*.ts" -o -name "*.tsx" | sort
```

Also find existing test files:

```bash
find <repo-path>/src -type f -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" | sort
```

Read each source file before reviewing it.

---

## Step 3: Review Each File

For every source file, evaluate all four dimensions:

### 3a. Acceptance Criteria
Go through each AC item from the plan. For each one, determine:
- **Pass** — the code satisfies it
- **Fail** — the code does not satisfy it
- **Partial** — partially addressed, needs more work
- **N/A** — not applicable to this file

### 3b. Best Practices
Check for language- and framework-appropriate best practices. For TypeScript/React Native:
- Types are strict (no implicit `any`, no type assertions without justification)
- No magic numbers or strings — use named constants
- Pure functions where possible; side effects are isolated
- Exported items are correctly typed
- Naming is clear and consistent (camelCase variables, PascalCase types)
- No dead code or unused imports
- File does one thing (single responsibility)

### 3c. Edge Conditions
Look for unhandled scenarios:
- Null / undefined inputs
- Empty arrays, zero-length strings
- Integer overflow or boundary values (e.g., colorIndex wrapping)
- Async race conditions or missing await
- SQLite type coercions (e.g., is_starred as 0|1 vs boolean)
- Off-by-one errors in pagination or index math
- Behavior at the first entry (no previous entry to derive colorIndex from)

### 3d. Tests
For each source file:
- Does a corresponding test file exist?
- If yes — do the tests cover the main functionality (happy path + key edge cases)?
- If no — flag it as **missing tests**

---

## Step 4: Output the Review

Present findings in this structure:

```
## Review: <stream-name>

### Acceptance Criteria
| # | Criterion | Status | Notes |
|---|-----------|--------|-------|
| 1 | Entry type exported and agreed upon | ✅ Pass | |
| 2 | All fields required by other streams are present | ✅ Pass | |
| 3 | Schema documented and versioned (migration v1) | ✅ Pass | |

### File Reviews

#### src/types/Entry.ts
**Best Practices**
- ✅ ...
- ⚠️ ...
- ❌ ...

**Edge Conditions**
- ⚠️ `colorIndex` wrapping: `rowToEntry` does not validate `color_index >= 0` — a negative value from DB would produce unexpected palette lookups
- ...

**Tests**
- ❌ No test file found — missing coverage for `rowToEntry`, `entryToRow`, and round-trip mapping

---

#### src/db/schema.ts
...
```

Use:
- ✅ for passing / no issue
- ⚠️ for a concern worth addressing
- ❌ for a clear problem or missing requirement

---

## Step 5: Summary & Next Steps

After all file reviews, output:

```
### Summary
- X of Y acceptance criteria passing
- Z issues found (A ❌ critical, B ⚠️ warnings)
- N files missing tests

### Recommended Actions
1. ...
2. ...
```

Then ask: "Want me to fix the issues and write the missing tests?"

---

## Notes

- Do not rewrite code during the review — only report findings
- If the user says "fix it" or "write the tests" after the review, proceed to implement
- Tests should live alongside source files: `src/types/Entry.test.ts`, `src/db/schema.test.ts`, etc.
- Test framework default: **Jest** (standard for React Native projects)
