# Quality Checklist Reference

The quality checklist in stream-plan front-loads the concerns that review-stream's three agents verify after implementation. By defining "what passing looks like" during planning, streams spend fewer cycles in review.

## Mapping to Review Agents

```
stream-plan Quality Checklist    →    review-stream Agent
─────────────────────────────         ────────────────────
Principle Compliance             →    Quality Agent (GP checks)
Simplicity                       →    Quality Agent (simplicity, DRY, elegance)
Convention Compliance            →    Quality Agent (codebase conventions)
Scope Discipline                 →    Quality Agent (no scope creep)
Error Handling                   →    Correctness Agent (error handling completeness)
Edge Cases                       →    Correctness Agent (edge case handling)
Tests                            →    Correctness Agent (integration correctness)
AC Coverage                      →    AC Verification Agent (pass/fail per criterion)
```

## Quality Categories

### 1. Principle Compliance

**What review checks:** For each guiding principle, does the code follow it? Violations flagged with GP ID and evidence.

**What planning defines:**
- Which principles apply to this stream (by GP-ID)
- The concrete approach for satisfying each
- Risk areas where violations are likely
- Existing code examples that demonstrate compliance

**Example:**
```markdown
| GP-2: External calls behind adapters | Create `adapters/email.ts` with interface; service layer calls adapter, never SDK directly | Risk: temptation to inline SDK calls in handler for "just one use" |
```

### 2. Simplicity

**What review checks:** Unnecessary abstraction, over-engineering, premature generalization, dead code.

**What planning defines:**
- The minimum set of new abstractions (ideally zero)
- Why each new file/module/type exists
- What was considered and rejected as unnecessary

**Questions to answer during planning:**
- Can this be done without a new abstraction?
- Is there an existing utility/pattern that already does this?
- If introducing a new pattern, will at least 2 streams use it?

### 3. Convention Compliance

**What review checks:** Does the code follow codebase conventions — naming, structure, imports, patterns?

**What planning defines:**
- Which stack guidelines (SG-IDs) apply
- Which existing patterns in the codebase to follow (with file references)
- Any new patterns being introduced and why they don't conflict

**Key signals from codebase exploration:**
- How are similar features structured?
- What naming convention do existing files follow?
- How are tests organized relative to source?
- What error types/patterns are already in use?

### 4. Scope Discipline

**What review checks:** Does the code do more than the stream's AC requires? Unrelated refactors, bonus features, "while I'm here" changes.

**What planning defines:**
- Explicit **in-scope** boundary
- Explicit **out-of-scope** list (things that are tempting but belong to other streams)
- If touching shared code, the minimum change needed

**Red flags to surface during planning:**
- "We should also..." — probably out of scope
- "While we're in this file..." — is the change required by this stream's AC?
- "This would be cleaner if we refactored..." — is the refactor a prerequisite or a nice-to-have?

### 5. Error Handling

**What review checks:** Are errors handled? Do they propagate context? Are failure modes covered?

**What planning defines:**
- Every failure mode: what can fail, how it fails, what the user/caller sees
- Error wrapping strategy (per guiding principles)
- Which errors are recoverable vs. fatal
- What error messages look like

**Failure mode template:**
```markdown
| Failure | Cause | User Sees | Recovery |
|---------|-------|-----------|----------|
| DB connection lost | Network/crash | "Unable to save — retrying" | Auto-retry 3x, then surface error |
| Invalid input | Bad user data | Validation message with field | User corrects and resubmits |
| Permission denied | Auth failure | 403 with reason | User re-authenticates |
```

### 6. Edge Cases

**What review checks:** Does the code handle boundary conditions, unusual inputs, concurrent access?

**What planning defines:**
- Each edge case identified during clarifying questions
- Expected behavior for each
- Whether the edge case needs a test or is handled by type constraints

**Common edge case categories:**
- Empty/null/missing inputs
- Very large inputs (memory, performance)
- Concurrent access (race conditions)
- Partial failures (some items succeed, some fail)
- First use / no data state
- Permission boundaries

### 7. Testability

**What review checks:** Do tests exist? Do they cover the AC? Do they follow existing patterns?

**What planning defines:**
- What needs tests (every AC should map to at least one test)
- What kind of tests: unit (isolated logic), integration (with real dependencies), end-to-end (full flow)
- Which existing test patterns to follow (file naming, setup/teardown, assertion style)
- What does NOT need tests (trivial wiring, framework boilerplate)
- Test data strategy: fixtures, factories, inline

## Using the Checklist

During stream planning (Step 5), walk through each category and define what "passing" looks like for the specific stream. This produces the `## Quality Checklist` section in the stream's `plan.md`.

During stream review, the review agents verify these same concerns — but now they have a concrete definition of "correct" to check against, rather than applying generic heuristics.

```
Planning defines "what correct looks like"
    ↓
Implementation follows the plan
    ↓
Review verifies against the plan's definition of correct
    ↓
Fewer review iterations, faster convergence
```
