# Project Lifecycle

The full lifecycle from idea to merged code, broken into phases. Each phase is a skill or sub-skill invocation.

---

## Phase Overview

```
1. CREATE        → git init, meta branch, registry
2. REQUIREMENTS  → gather, discuss, define edge cases, write requirements.md
3. DESIGN        → high-level architecture, language-specific refinement, tradeoff review
4. DECOMPOSE     → break into streams with AC, dependencies, wave plan
5. IMPLEMENT     → worktree per stream, plan mode, code
6. REVIEW        → PR creation, review, feedback cycle
7. MERGE         → merge to main, cleanup worktree, update meta
```

---

## Phase 1: Create (skill: `create-project`)

Already defined. Creates repo, orphan `meta` branch, registry entry.

**Output on meta:** `plan.md`, `session.md`, `tasks.md`

---

## Phase 2: Requirements (skill: `project-requirements`)

### Purpose
Turn a project objective into a concrete, testable requirements document.

### Flow

1. **Discuss** — Conversational exploration with the user:
   - What problem is being solved?
   - Who are the users/stakeholders?
   - What does success look like?
   - What are the constraints (tech stack, timeline, dependencies)?

2. **Distill** — For each capability identified, define:
   - **Behavior**: what it does (plain language)
   - **Acceptance criteria**: Given-When-Then scenarios
   - **Edge cases**: what happens when inputs are invalid, empty, concurrent, too large, missing permissions, etc.
   - **Non-requirements**: what is explicitly out of scope

3. **Review** — Present requirements back to user for confirmation. Walk through edge cases one by one (per user preference). Ask:
   - "Is anything missing?"
   - "Is anything over-specified?"
   - "Are there constraints I haven't captured?"

4. **Commit** — Write `requirements.md` to meta branch.

### `requirements.md` Format

```markdown
# Requirements: <project-name>

## Problem Statement
<what problem this project solves and for whom>

## Constraints
- <tech stack, timeline, external dependencies, etc.>

## Capabilities

### 1. <Capability Name>

**Behavior**: <plain language description>

**Acceptance Criteria**:
- Given <precondition>, when <action>, then <expected result>
- Given <precondition>, when <action>, then <expected result>

**Edge Cases**:
- <scenario>: <expected behavior>
- <scenario>: <expected behavior>

---

### 2. <Capability Name>
...

## Non-Requirements
- <what is explicitly out of scope>

## Open Questions
- <unresolved items to revisit>
```

---

## Phase 3: Design (skill: `project-design`)

### Purpose
Produce a high-level technical design informed by requirements, refined against language/framework best practices, with tradeoffs surfaced to the user.

### Flow

1. **Propose** — Read `requirements.md` from meta. Produce initial design:
   - System architecture (components, data flow, boundaries)
   - Data model (entities, relationships, storage)
   - API surface (if applicable)
   - Key technical decisions with rationale

2. **Refine** — Apply language/framework best practices:
   - Read existing codebase for conventions (if repo has code)
   - Check against known patterns for the stack (e.g., Rust error handling, React state management)
   - Identify where the design violates idioms or introduces unnecessary complexity
   - Suggest simplifications

3. **Tradeoffs** — Surface decisions that have meaningful tradeoffs. Present each as:
   - **Decision**: what needs to be decided
   - **Options**: 2-3 concrete approaches
   - **Tradeoffs**: pros/cons of each (performance, complexity, maintainability, flexibility)
   - **Recommendation**: which option and why
   - Walk through one at a time, get user's call before proceeding.

4. **Commit** — Write `design.md` to meta branch.

### `design.md` Format

```markdown
# Design: <project-name>

## Architecture

### Overview
<high-level description of the system>

### Components
<component diagram or description — what are the major pieces and how do they connect>

### Data Model
<entities, relationships, storage approach>

### API Surface
<endpoints, commands, events — whatever the system's interface is>

## Technical Decisions

### 1. <Decision Title>
- **Context**: <why this decision matters>
- **Decision**: <what was decided>
- **Alternatives considered**: <what else was evaluated>
- **Rationale**: <why this option was chosen>

### 2. <Decision Title>
...

## Language & Framework Considerations
<patterns, idioms, and conventions applied from the chosen stack>

## Risks
- <known risks and mitigation strategies>
```

---

## Phase 4: Decompose (skill: `project-decompose`)

### Purpose
Break the design into implementable streams with acceptance criteria, dependencies, and a wave plan.

### Flow

1. **Identify streams** — Read `requirements.md` and `design.md` from meta. Map capabilities and components to streams:
   - Each stream should be independently implementable and reviewable
   - Each stream should take no more than a few sessions to complete
   - Prefer vertical slices (end-to-end through a feature) over horizontal layers

2. **Define high-level AC per stream** — For each stream:
   - Pull relevant acceptance criteria from requirements (high-level, behavioral)
   - Brief description of what "done" means
   - Do NOT go into implementation detail here — that happens in the stream design pass (Phase 5)

3. **Map dependencies** — Identify which streams block others:
   - Direct: stream B needs stream A's code/types/schema
   - Data: stream B needs stream A's migrations or seed data
   - API: stream B calls endpoints/functions defined in stream A

4. **Wave plan** — Group streams into waves:
   - Wave 1: streams with no blockers
   - Wave N: streams whose blockers are all in earlier waves
   - Within a wave, all streams are independent and can run in parallel

5. **Review with user** — Present the decomposition:
   - Stream list with AC summaries
   - Dependency graph
   - Wave plan
   - Ask: "Does this grouping make sense? Should any streams be split or merged?"

6. **Commit** — Update `plan.md` with stream table and wave plan. Create `streams/<name>/plan.md` for each stream. All on meta branch.

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

### Stream `plan.md` Format (after decomposition)

```markdown
# Plan: <stream-name>

## Objective
<what this stream delivers>

## Acceptance Criteria
- [ ] Given <precondition>, when <action>, then <result>
- [ ] <implementation criterion>
- [ ] Tests pass, no regressions
- [ ] PR reviewed and approved

## Tasks
- [ ] <task 1>
- [ ] <task 2>

## Dependencies
- Blocked by: <stream-names or "none">
- Blocks: <stream-names or "none">

## Notes
```

---

## Phase 5: Stream Design & Implement (skill: `open-stream`)

### Purpose
Design a stream at implementation level, get user approval, then open it for work in an isolated worktree.

### Worktree Convention

All worktrees live in a standardized location relative to the repo:

```
<repo-root>/.worktrees/<stream-name>/
```

Add `.worktrees` to `.gitignore` in the repo.

### Flow

#### Step 1: Check Readiness

Read `plan.md` from meta. Verify the stream is `unblocked` or `in-progress`. If blocked, tell the user what's blocking it and stop.

#### Step 2: Stream Design Pass

This is where the high-level project AC gets refined into a low-level, implementation-ready stream plan. Read `requirements.md`, `design.md`, and the stream's `plan.md` from meta, plus the existing codebase.

**2a. Codebase Exploration** — Understand what exists:
- Read existing code patterns, conventions, and abstractions relevant to this stream
- Identify integration points with code from already-merged streams
- Note any existing tests, types, or utilities to build on
- List key files that will be read or modified

**2b. Clarifying Questions** — Surface ambiguities before planning:
- Edge cases: invalid inputs, empty states, concurrent access, large data, missing permissions
- Error handling: what fails, how it fails, what the user sees
- Integration points: how this stream connects to existing code and other streams
- Scope boundaries: what's in, what's explicitly out
- Backward compatibility: does this change existing behavior?
- Performance: are there constraints on speed, memory, or payload size?
- Present questions to user and **wait for answers before proceeding**

**2c. Architecture & Approach** — Design the implementation:
- Propose concrete approach: files to create/modify, patterns to follow, data flow
- Apply language/framework best practices and existing codebase conventions
- If multiple viable approaches exist, present options with tradeoffs and recommendation
- **Ask user which approach they prefer** (or confirm recommendation)

**2d. Refine AC** — Expand the high-level AC into implementation-level criteria:
- Convert behavioral AC from requirements into concrete, testable checks
- Add implementation criteria: migrations, type exports, error states, edge case handling
- Add quality criteria: tests pass, no regressions, follows codebase conventions
- Each AC should be independently verifiable during review

**2e. Task Breakdown** — Break the stream into ordered tasks:
- Each task should be a single commit-sized unit of work
- Tasks should build on each other (order matters)
- Include test tasks alongside implementation tasks

**2f. Review Plan with User** — Present the full stream plan:
- Approach summary
- Refined AC checklist
- Task list with order
- Files to create/modify
- Ask: "Does this plan look right? Ready to start implementation?"
- **Do not proceed until the user explicitly approves.**

#### Step 3: Commit Stream Plan to Meta

Update `streams/<name>/plan.md` on meta with the refined plan from Step 2.

#### Step 4: Create Worktree

```bash
cd <repo-root>
git worktree add .worktrees/<stream-name> -b stream/<stream-name> main
```

#### Step 5: Generate CLAUDE.md

Dynamically build from current meta state:

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

Write to `<worktree-root>/CLAUDE.md`.

#### Step 6: Update Meta

Set stream status to `in-progress` in `plan.md` on meta branch.

#### Step 7: Launch

Open Claude session in the worktree directory (via terminal tab or tmux window).

### Implementation Guidelines

- Start in plan mode (`--permission-mode plan`)
- Keep implementation to 30-minute blocks aligned with task plan
- Commit frequently on the stream branch — one commit per task when practical
- When all AC are met, signal readiness for review

### Refined Stream `plan.md` Format (after design pass)

```markdown
# Plan: <stream-name>

## Objective
<what this stream delivers>

## Approach
<concrete implementation strategy — patterns, data flow, key decisions>

## Acceptance Criteria
- [ ] Given <precondition>, when <action>, then <result>
- [ ] <edge case>: <expected behavior>
- [ ] <error scenario>: <expected behavior>
- [ ] <implementation criterion — e.g., migrations run cleanly>
- [ ] <quality criterion — e.g., tests pass, no regressions>
- [ ] PR reviewed and approved

## Tasks
1. [ ] <task — commit-sized unit of work>
2. [ ] <task>
3. [ ] <task — includes tests>

## Files
- Create: <new files>
- Modify: <existing files>

## Dependencies
- Blocked by: <stream-names or "none">
- Blocks: <stream-names or "none">

## Decisions
- <decision made during design pass with brief rationale>

## Notes
<edge cases, open questions resolved during clarification>
```

---

## Phase 6: Review (skill: `review-stream`)

### Purpose
Review the stream's work against its AC, iterate until passing, then create a draft PR with user approval.

### Flow

1. **Review against AC** — For each acceptance criterion:
   - Verify it's met by reading the code
   - Present findings one at a time (per user preference)
   - Flag gaps, suggest fixes

2. **Iterate** — If changes needed:
   - Make fixes in the worktree
   - Commit on the stream branch
   - Re-review until all AC pass

3. **Request approval to create PR** — When all AC pass, present a summary:
   - List of commits on the stream branch
   - AC checklist (all checked)
   - Any notes or caveats
   - Ask: "Ready to create a draft PR?"
   - **Do not create a PR until the user explicitly approves.**

4. **Create draft PR** (only after user approval):
   ```bash
   cd <worktree>
   git push -u origin stream/<stream-name>
   gh pr create --draft \
     --title "<stream-name>: <brief description>" \
     --body "<AC checklist from stream plan.md>"
   ```

5. **Mark ready** — Only when the user explicitly requests it:
   ```bash
   gh pr ready
   ```

---

## Phase 7: Merge (skill: `merge-stream`)

### Purpose
Merge the stream's PR, clean up, and update project state.

### Flow

1. **Merge PR**:
   ```bash
   gh pr merge --squash
   ```

2. **Clean up worktree**:
   ```bash
   cd <repo-root>
   git worktree remove .worktrees/<stream-name>
   git branch -d stream/<stream-name>
   ```

3. **Update meta** — On the meta branch:
   - Set stream status to `complete` in `plan.md`
   - Check if any blocked streams are now unblocked (all their blockers are `complete`)
   - Update those streams to `unblocked`

4. **Notify** — Tell the user:
   - Which stream was merged
   - Which streams are now unblocked
   - What the next wave looks like

5. **Rebase remaining worktrees** — For any active worktrees on other streams:
   ```bash
   cd <worktree>
   git rebase main
   ```
   Warn the user if conflicts arise.
