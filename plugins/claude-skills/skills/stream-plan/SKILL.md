---
name: stream-plan
description: Stream-level planning — implementation design, best practices, quality checklist, and guiding principle compliance. Called when opening a stream for design (Phase 5) or invoked directly. Reads guiding principles from design.md and produces a refined stream plan.md with concrete approach, principle compliance mapping, and front-loaded quality checks.
version: 1.0.0
---

# Stream Plan

Designs a stream at implementation level by exploring the codebase, surfacing questions, discovering best practices, and mapping the approach against the project's guiding principles. Front-loads the quality and correctness concerns that verify checks — catching issues in planning rather than after implementation.

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

Launch 3 **agents** in parallel, modeled after verify's 3-agent pattern but focused on **planning** rather than review:

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

**Do not batch questions. Ask one, wait for the answer, incorporate it, then ask the next.**

**Do not proceed to Step 4 until all questions are resolved.**

### Step 4: Architecture & Approach

Propose the concrete implementation approach:

1. **Files** — what to create, what to modify (with brief rationale for each)
2. **Patterns** — which existing codebase patterns to follow, which new patterns to introduce
3. **Data flow** — how data moves through this stream's code
4. **Integration** — how this connects to existing code and other streams

If multiple viable approaches exist, present each as:
- **Option**: brief description
- **Tradeoffs**: complexity, principle compliance, testability, performance
- **Recommendation**: which and why

**Present one option at a time. Get the user's decision before proceeding.**

### Step 5: Quality Checklist

Front-load the concerns that verify's quality and correctness agents check. For each category, define what "passing" looks like **for this specific stream**:

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

Break the stream into ordered tasks:

- Each task is a single commit-sized unit of work
- Tasks build on each other (order matters)
- Include test tasks alongside implementation tasks
- For each task, note which guiding principles and quality checks it must satisfy

### Step 8: Review Plan with User

Present the full stream plan:

1. Approach summary
2. Principle compliance map (which GPs apply, how each is satisfied)
3. Quality checklist
4. Refined AC checklist
5. Task list with order
6. Files to create/modify

**Walk through each section one at a time. Get explicit approval on each before moving to the next.**

**Do not proceed until the user explicitly approves the full plan.**

### Step 9: Commit Stream Plan to Meta

Commit to meta using a temporary worktree to avoid touching the user's working tree:

```bash
cd <repo-path>
git worktree add /tmp/meta-work meta/<project-slug>
```

Use the **Write tool** to update `/tmp/meta-work/streams/<name>/plan.md` with the refined plan. Then:

```bash
cd /tmp/meta-work
git add streams/<name>/plan.md
git commit -m "meta: refined stream plan — <stream-name>"
```

If a remote is configured, push:

```bash
git push origin meta/<project-slug>
```

Clean up:

```bash
cd <repo-path>
git worktree remove /tmp/meta-work
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

## Tasks
1. [ ] <task — commit-sized unit of work>
2. [ ] <task>
3. [ ] <task — includes tests>

## Files
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
- **Quality checklist front-loads verification.** The verify skill will check these same concerns — catching them here means fewer iterations.
- **Best practices are filtered through principles.** A "best practice" that conflicts with a guiding principle is not applicable to this project. Surface the conflict rather than silently adopting one over the other.
- **Questions are asked one at a time.** Never batch multiple questions into a single message. Ask, wait, incorporate, then ask the next.
- **Use the Write tool for creating files, Edit tool for modifying files, and Read tool for reading files.** Only use Bash for git commands and directory creation.
- **If a principle needs amendment**, update `design.md` on meta before finalizing the stream plan. The principle set must be consistent across all streams.

---

## Quality Checklist Reference

See [references/quality-checklist.md](references/quality-checklist.md) for the full quality framework and how it maps to verify's agents.
