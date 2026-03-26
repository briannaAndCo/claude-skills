---
name: stream-plan
description: Stream-level planning — implementation design, best practices, quality checklist, and guiding principle compliance. Called when opening a stream for design (Phase 5) or invoked directly. Reads guiding principles from design.md and produces a refined stream plan.md with concrete approach, principle compliance mapping, and front-loaded quality checks.
version: 1.0.0
---

# Stream Plan

Designs a stream at implementation level by exploring the codebase, surfacing questions, discovering best practices, and mapping the approach against the project's guiding principles. Front-loads the quality and correctness concerns that review-stream checks — catching issues in planning rather than after implementation.

**Input from meta:** `design.md` (guiding principles, architecture, stack guidelines), `requirements.md`, stream's `plan.md` (high-level AC from decomposition)

**Output on meta:** refined `streams/<name>/plan.md`

---

## Flow

### Step 1: Read Context

Use Bash to read planning state from meta:

```bash
cd <repo-path>
git show meta/<project-slug>:design.md
git show meta/<project-slug>:requirements.md 2>/dev/null || true
git show meta/<project-slug>:plan.md
git show meta/<project-slug>:streams/<stream-name>/plan.md
```

Extract:
- The stream's objective and high-level AC
- All guiding principles (GP-1 through GP-N) — these are the contract
- Stack guidelines (SG-1 through SG-N) — these are the implementation conventions
- Architecture components relevant to this stream
- Use cases this stream touches

Verify the stream is `unblocked` or `in-progress` in `plan.md`. If blocked, tell the user what's blocking it and stop.

### Step 2: Parallel Discovery

Launch 3 **agents** in parallel, modeled after review-stream's 3-agent pattern but focused on **planning** rather than review:

#### Agent 1: Codebase Explorer
- Map existing code patterns, conventions, and abstractions relevant to this stream
- Identify integration points with code from already-merged streams
- Find existing tests, types, or utilities to build on
- Check how existing code implements each applicable guiding principle — find concrete examples
- Return: list of key files, existing patterns to follow, integration points

#### Agent 2: Principle Compliance Planner
- For each guiding principle in `design.md`, determine:
  - **Applicable?** — Does this principle affect this stream's work?
  - **How?** — What concrete pattern or approach satisfies it in the context of this stream?
  - **Risk** — Where might this stream accidentally violate it?
  - **Existing examples** — How do already-implemented streams handle this principle?
- Return: principle compliance map with applicable GPs, approach for each, risk areas

#### Agent 3: Best Practices Researcher
- Search the web for best practices relevant to this stream's **domain** (not language):
  - If the stream involves auth → search for authentication/authorization best practices
  - If it involves data modeling → search for data modeling patterns
  - If it involves API design → search for API design best practices
  - If it involves file I/O → search for file handling best practices
- Filter results through the project's guiding principles — discard practices that conflict
- Cross-reference with the project's stack guidelines for implementation-specific patterns
- Return: relevant practices with sources, mapped to applicable guiding principles

After all agents return, use the **Read tool** to read all key files identified by Agent 1.

### Step 3: Surface Questions

Review the agent results and identify ambiguities. Present questions to the user **one at a time** — ask one question, wait for the answer, then ask the next.

Categories of questions to surface (in priority order):

1. **Principle conflicts** — "GP-3 says each module has a single entry point, but this stream needs to expose both a sync and async API. Should we use a single entry point with both, or request a principle amendment?"
2. **Scope boundaries** — "Should this stream handle <edge case> or is that out of scope?"
3. **Integration points** — "Stream X established <pattern> for <thing>. Should this stream follow the same pattern or is there a reason to diverge?"
4. **Error handling** — "When <failure scenario> happens, what should the user see?"
5. **Edge cases** — "What happens when <input is empty / concurrent access / data is too large / permissions are missing>?"
6. **Performance** — "Are there constraints on <speed / memory / payload size> for this stream's work?"
7. **Backward compatibility** — "This stream changes <existing behavior>. Is that acceptable?"
8. **Side effects** — "This change touches <shared code / common utility / widely-used type>. Are we confident this won't break other consumers?"
9. **Oddities** — Anything that seems unusual, inconsistent, or suspicious. "This file is imported but never used", "This pattern doesn't match how the rest of the codebase does it", "This dependency seems unnecessary". Flag it and ask.

**Do not batch questions. Ask one, wait for the answer, incorporate it, then ask the next.**

**Do not proceed to Step 4 until all questions are resolved.**

### Step 4: Architecture & Approach

Propose the concrete implementation approach:

1. **Files** — what to create, what to modify (with brief rationale for each)
2. **Patterns** — which existing codebase patterns to follow, which new patterns to introduce
3. **Data flow** — how data moves through this stream's code
4. **Integration** — how this connects to existing code and other streams
5. **PR Breakdown** — split the work into separate PRs (see Step 4a)

If multiple viable approaches exist, present each as:
- **Option**: brief description
- **Tradeoffs**: complexity, principle compliance, testability, performance
- **Recommendation**: which and why

**Present one option at a time. Get the user's decision before proceeding.**

#### Step 4a: PR Breakdown

Evaluate whether the stream's work should be split across multiple PRs. The ideal PR touches **8 files or fewer**. Each PR should be:

- **Self-contained** — mergeable on its own without breaking anything
- **Modular** — focused on a single concern or layer (e.g., data model, API, UI)
- **Ordered** — later PRs can depend on earlier ones, but not vice versa

For each proposed PR, specify:
- **Title** — short description of what the PR delivers
- **Files** — list of files created/modified (with count)
- **Depends on** — which prior PRs must merge first (if any)
- **Potential improvements** — things that could be done better, added, or cleaned up as part of this PR. **Ask the user** whether to include each improvement or defer it.

If the stream fits in a single PR of ≤8 files, say so — don't split for the sake of splitting.

**Question anything that seems strange:** If a file change seems unrelated, a dependency seems unnecessary, or a pattern feels inconsistent with the rest of the codebase, flag it. Ask about potential side effects before including it in the plan.

### Step 5: Quality Checklist

Front-load the concerns that review-stream's quality and correctness agents check. For each category, define what "passing" looks like **for this specific stream**:

#### Simplicity
- What is the minimum set of abstractions needed?
- Are there any unnecessary layers or indirection?

#### Convention Compliance
- Which stack guidelines (SG-IDs) apply?
- Which existing codebase patterns must be followed?

#### Scope Discipline
- What is explicitly **in** scope?
- What is explicitly **out** of scope?
- What might tempt scope creep during implementation?

#### Error Handling
- What can fail?
- How does each failure surface to the user/caller?
- Are errors wrapped with context per GP (if applicable)?

#### Edge Cases
- List each edge case identified in Step 3
- Define expected behavior for each

#### Testability
- What needs tests?
- What kind of tests (unit, integration, end-to-end)?
- What existing test patterns to follow?

Present the quality checklist to the user. **Walk through each category one at a time. Get confirmation.**

### Step 6: Refine AC

Expand the high-level AC into implementation-level criteria:

- Convert behavioral AC from requirements into concrete, testable checks
- Add implementation criteria: migrations, type exports, error states, edge case handling
- Add quality criteria from Step 5: tests pass, no regressions, follows conventions
- Add principle compliance criteria: one AC per applicable guiding principle
- Each AC should be independently verifiable during review

### Step 7: Task Breakdown

Break the stream into ordered tasks, **organized by PR**:

- Group tasks under the PR they belong to (from Step 4a)
- Each task is a single commit-sized unit of work
- Tasks build on each other within a PR (order matters)
- Include test tasks alongside implementation tasks
- For each task, note which guiding principles and quality checks it must satisfy
- If a task seems like it could cause side effects or touches shared code, flag it explicitly

### Step 8: Review Plan with User

Present the full stream plan:

1. Approach summary
2. PR breakdown (number of PRs, file counts, dependencies between PRs)
3. Principle compliance map (which GPs apply, how each is satisfied)
4. Quality checklist
5. Refined AC checklist
6. Task list organized by PR
7. Files to create/modify

**Walk through each section one at a time. Get explicit approval on each before moving to the next.**

**Do not proceed until the user explicitly approves the full plan.**

### Step 9: Commit Stream Plan to Meta

Use the **Write tool** to update `streams/<name>/plan.md` with the refined plan. Then commit:

```bash
cd <repo-path>
git checkout meta/<project-slug>
git add streams/<name>/plan.md
git commit -m "meta: refined stream plan — <stream-name>"
git checkout <original-branch>
```

If a remote is configured, push:

```bash
git push origin meta/<project-slug>
```

---

## Refined Stream `plan.md` Format

```markdown
# Plan: <stream-name>

## Objective
<what this stream delivers>

## Approach
<concrete implementation strategy — patterns, data flow, key decisions>

## Principle Compliance

| Principle | Approach | Risk Areas |
|-----------|----------|------------|
| GP-1: <statement> | <how this stream satisfies it> | <where violations might occur> |
| GP-3: <statement> | <how this stream satisfies it> | <where violations might occur> |

## Stack Guidelines Applied
- SG-2: <guideline> — applied in <where>
- SG-4: <guideline> — applied in <where>

## Quality Checklist
- [ ] **Simplicity**: <specific check for this stream>
- [ ] **Conventions**: follows <specific patterns>
- [ ] **Scope**: only implements <bounded scope>, explicitly excludes <out-of-scope items>
- [ ] **Error handling**: <specific failure scenarios handled>
- [ ] **Edge cases**: <specific edge cases covered>
- [ ] **Tests**: <specific test requirements>

## Acceptance Criteria
- [ ] Given <precondition>, when <action>, then <result>
- [ ] <edge case>: <expected behavior>
- [ ] <error scenario>: <expected behavior>
- [ ] <implementation criterion>
- [ ] <principle compliance criterion — e.g., "All DB access goes through repository layer (GP-2)">
- [ ] <quality criterion — e.g., tests pass, no regressions>
- [ ] PR reviewed and approved

## PR Breakdown

### PR 1: <title> (<N> files)
**Files:** <list of files created/modified>
**Depends on:** none
**Potential improvements:** <improvements discussed with user, with disposition: included / deferred>

#### Tasks
1. [ ] <task — commit-sized unit of work>
2. [ ] <task>
3. [ ] <task — includes tests>

### PR 2: <title> (<N> files)
**Files:** <list of files created/modified>
**Depends on:** PR 1
**Potential improvements:** <improvements discussed with user>

#### Tasks
1. [ ] <task>
2. [ ] <task>

## All Files
- Create: <new files with brief rationale>
- Modify: <existing files with brief rationale>

## Dependencies
- Blocked by: <stream-names or "none">
- Blocks: <stream-names or "none">

## Decisions
- <decision made during planning with brief rationale>

## Notes
<edge cases resolved, questions answered, best practices adopted>
```

---

## Important Notes

- **Principle compliance is not optional.** Every applicable guiding principle must have an explicit entry in the compliance table. If a principle can't be satisfied, surface it to the user and propose amending `design.md` before proceeding.
- **Quality checklist front-loads review.** The review-stream skill will verify these same concerns — catching them here means fewer review iterations.
- **Best practices are filtered through principles.** A "best practice" that conflicts with a guiding principle is not applicable to this project. Surface the conflict rather than silently adopting one over the other.
- **PRs should be ≤8 files.** If a stream touches more than 8 files, split into multiple modular PRs. Each PR should be self-contained and mergeable on its own. Don't split artificially if the work naturally fits in one PR.
- **Include model recommendations in the plan.** For each task or PR in the breakdown, note the recommended model tier:
  - **Mechanical** (Haiku/fast): boilerplate, single-file changes, config updates, simple tests
  - **Standard** (Sonnet): multi-file features, integration work, pattern-following implementation
  - **Complex** (Opus): architecture decisions, cross-cutting refactors, design review, complex debugging
  This helps the implementer (human or agent) choose the right model per task, reducing cost on routine work and ensuring quality on complex work.
- **Question oddities and side effects.** If something seems strange, inconsistent, or could have unintended consequences, flag it. Don't silently proceed past potential issues. Surface potential improvements and ask the user whether to include or defer them.
- **Questions are asked one at a time.** Never batch multiple questions into a single message. Ask, wait, incorporate, then ask the next.
- **Use the Write tool for creating files, Edit tool for modifying files, and Read tool for reading files.** Only use Bash for git commands and directory creation.
- **If a principle needs amendment**, update `design.md` on meta before finalizing the stream plan. The principle set must be consistent across all streams.

---

## Quality Checklist Reference

See [references/quality-checklist.md](references/quality-checklist.md) for the full quality framework and how it maps to review-stream's agents.
