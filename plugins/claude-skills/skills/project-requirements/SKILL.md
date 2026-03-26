---
name: project-requirements
description: Requirements gathering and analysis from source documents and user input. Called after create-project and before project-plan. Ingests documents (PRDs, specs, notes, transcripts), extracts capabilities, surfaces questions and issues one at a time, and produces a structured requirements.md on the meta branch. Supports document files, typed input, or both.
version: 1.0.0
---

# Project Requirements

Turns source material — documents, notes, typed context, or conversation — into a structured, testable requirements document. Focuses on extracting *what* the system must do, surfacing ambiguities, identifying edge cases, and establishing naming conventions — all before any design or architecture work begins.

**Input:** Source documents (files) and/or typed context from the user
**Output on meta:** `requirements.md`

---

## Flow

### Step 1: Gather Source Material

Ask the user how they'd like to provide requirements context. Support three modes:

1. **Documents** — User provides file paths (PRDs, specs, design docs, meeting notes, Slack exports, emails, etc.). Read each file using the **Read tool**.
2. **Typed input** — User types context directly at the prompt. Accept as much as they want to provide. When they signal they're done (e.g., "that's it", "done", "next"), proceed.
3. **Both** — Documents plus additional typed context.

Prompt:

> "How would you like to provide the requirements source material?
> - Paste or type it in directly
> - Give me file paths to read (docs, specs, notes, etc.)
> - Both
>
> You can also add more context at any point during the process."

If the repo already has code, also ask:

> "Should I explore the existing codebase for additional context? (This helps me understand what's already built and what conventions exist.)"

If yes, launch 2-3 **Explore agents** in parallel to:
- Map existing features and capabilities
- Identify patterns, conventions, and domain terminology already in use
- Find any existing documentation (`README.md`, `docs/`, inline comments)
- Return a summary of what exists

### Step 2: Analyze Source Material

Once all source material is collected, analyze it in two phases:

#### Phase 1: Extract and Organize

Read all provided documents and typed input. Extract:

- **Problem statement** — what problem is being solved and for whom
- **Actors** — who or what interacts with the system
- **Capabilities** — distinct things the system must do (group by actor or domain area)
- **Constraints** — tech stack, timeline, dependencies, compliance, performance
- **Terminology** — domain-specific terms and their definitions as used in the source material

Present a brief summary back to the user:

> "Here's what I've extracted from the source material:
> - **Problem**: [one sentence]
> - **Actors**: [list]
> - **Capabilities found**: [count] across [domains]
> - **Constraints noted**: [list]
>
> Does this feel right before I dig deeper?"

**Wait for confirmation before proceeding.**

#### Phase 2: Expert Analysis

Launch 3 **agents** in parallel:

##### Agent 1: Gap Analyst
- Identify capabilities mentioned but not fully specified
- Find actors referenced without clear use cases
- Spot constraints that are implied but not stated
- Look for missing error/failure scenarios
- Check for missing non-functional requirements (performance, security, accessibility)
- Return: list of gaps with severity (critical / important / nice-to-have)

##### Agent 2: Conflict & Ambiguity Detector
- Find contradictions between different parts of the source material
- Identify ambiguous terms (same word used differently in different places)
- Spot requirements that could be interpreted multiple ways
- Find implicit assumptions that should be made explicit
- Return: list of conflicts/ambiguities with the conflicting passages quoted

##### Agent 3: Edge Case & Risk Scanner
- For each capability, identify boundary conditions
- Surface failure modes: what happens when inputs are invalid, empty, concurrent, too large, missing permissions
- Identify security-sensitive operations
- Find operations that could have unintended side effects
- Identify data integrity risks
- Return: list of edge cases and risks grouped by capability

### Step 3: Surface Questions

Using the expert analysis results, present questions to the user **one at a time**. Ask one question, wait for the answer, incorporate it, then ask the next.

Order questions by priority:

1. **Conflicts** — "The source material says [X] in one place and [Y] in another. Which is correct?"
2. **Critical gaps** — "There's no mention of what happens when [scenario]. What should the system do?"
3. **Ambiguous terms** — "[Term] is used to mean both [A] and [B]. Which meaning should we standardize on?"
4. **Naming** — "The source material uses [term-a] and [term-b] interchangeably. Which should be the canonical name?"
5. **Scope boundaries** — "Is [capability] in scope for this project, or is it a future concern?"
6. **Edge cases** — "What should happen when [boundary condition]?"
7. **Non-functional requirements** — "Are there performance/security/accessibility constraints for [capability]?"
8. **Important gaps** — "The source material doesn't specify [aspect]. Do you have a preference?"

For each question:
- Quote the relevant source material (if applicable)
- Explain why the question matters
- Offer a recommendation if one is reasonable
- Record the answer in the working requirements

**Do not batch questions. Ask one, wait, incorporate, then ask the next.**

After all critical and important questions are resolved, ask:

> "I have [N] remaining nice-to-have questions. Would you like to go through them now, or leave them as open questions in the requirements doc?"

### Step 4: Define Capabilities

For each capability identified, structure it using **EARS syntax** (Easy Approach to Requirements Syntax) where applicable:

- **Ubiquitous**: "The system shall [response]." — always true
- **Event-driven**: "When [trigger], the system shall [response]." — in response to an event
- **State-driven**: "While [state], the system shall [response]." — while a condition holds
- **Optional feature**: "Where [feature is enabled], the system shall [response]." — configurable
- **Unwanted behavior**: "If [condition], then the system shall [response]." — error/edge case handling

For each capability, define:

1. **Name** — clear, canonical name using the agreed terminology
2. **Behavior** — plain language description of what it does
3. **EARS requirements** — structured requirement statements using EARS patterns
4. **Acceptance criteria** — Given-When-Then scenarios that verify the behavior
5. **Edge cases** — boundary conditions and expected behavior (from Agent 3's analysis)
6. **Not included** — what this capability explicitly does NOT do (prevents scope creep)

Present capabilities to the user **one at a time**. For each:

> "Here's how I've structured [Capability Name]:
> [capability details]
>
> Does this capture the intent? Anything to add or change?"

**Wait for approval before moving to the next capability.**

### Step 5: Establish Terminology

Compile a glossary of domain terms from the source material and questions:

- **Term**: the canonical name
- **Definition**: what it means in this project's context
- **Aliases**: other terms used in source material that map to this (for searchability)
- **Not to be confused with**: similar terms that mean something different

Present the glossary to the user:

> "Here's the project terminology I've established. These names will carry through to design and implementation — files, variables, and APIs should use these terms."

**Walk through one at a time. Get confirmation.**

### Step 6: Adversarial Self-Review

Before presenting the final document, run a critical review. Launch an **Agent** to:

- Read the complete draft requirements as a skeptical reviewer
- Check: is every capability testable? Is every AC specific enough to verify?
- Check: are there circular dependencies between capabilities?
- Check: are non-requirements actually requirements in disguise?
- Check: does the terminology glossary cover all domain terms used in requirements?
- Check: are EARS requirement statements well-formed (correct pattern, no ambiguity)?
- Return: issues found with severity and suggested fixes

Present any critical issues to the user **one at a time** for resolution.

### Step 7: Compile and Review

Assemble the full `requirements.md`. Present the complete document to the user section by section:

1. Problem Statement
2. Actors
3. Constraints
4. Capabilities (with EARS requirements, AC, edge cases)
5. Non-Requirements
6. Terminology
7. Decision Log
8. Open Questions

**Walk through each section one at a time. Get explicit approval on each.**

Ask:

> "Is there anything you'd like to add, change, or remove before I commit this?"

### Step 8: Commit

Use the **Write tool** to create `requirements.md` in the repo root. Then commit to meta:

```bash
cd <repo-path>
git checkout meta
git add requirements.md
git commit -m "meta: add requirements"
git checkout <original-branch>
```

If a remote is configured, push:

```bash
git push origin meta
```

---

## `requirements.md` Format

```markdown
# Requirements: <project-name>

## Problem Statement
<what problem this project solves, for whom, and why it matters>

## Actors

| Actor | Type | Description |
|-------|------|-------------|
| <name> | user / service / system / external | <what they do> |

## Constraints
- <tech stack, timeline, external dependencies, compliance, performance, etc.>

## Capabilities

### CAP-1: <Capability Name>

**Behavior**: <plain language description>

**Requirements**:
- When <trigger>, the system shall <response>. *(EARS: event-driven)*
- While <state>, the system shall <response>. *(EARS: state-driven)*
- The system shall <response>. *(EARS: ubiquitous)*
- If <error condition>, then the system shall <response>. *(EARS: unwanted behavior)*

**Acceptance Criteria**:
- Given <precondition>, when <action>, then <expected result>
- Given <precondition>, when <action>, then <expected result>

**Edge Cases**:
- <scenario>: <expected behavior>
- <scenario>: <expected behavior>

**Not Included**:
- <what this capability explicitly does NOT do>

---

### CAP-2: <Capability Name>
...

## Non-Requirements
- <what is explicitly out of scope for the entire project>

## Terminology

| Term | Definition | Aliases | Not to be confused with |
|------|-----------|---------|------------------------|
| <term> | <definition in this project's context> | <other names used in source material> | <similar but different terms> |

## Decision Log

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | <question that was asked> | <what was decided> | <why> |
| 2 | <question> | <decision> | <rationale> |

## Source Material
- <list of documents/files that were analyzed>
- <typed input: noted as "user-provided context">

## Open Questions
- <unresolved items to revisit during design or implementation>
```

---

## Important Notes

- **Source documents are the starting point, not the final word.** The skill extracts, organizes, and challenges — it doesn't just transcribe.
- **Questions are asked one at a time.** Never batch multiple questions. Ask, wait, incorporate, then ask the next.
- **EARS syntax is the preferred format for requirement statements.** It provides structure without being overly formal. Use the pattern that best fits each requirement (event-driven, state-driven, ubiquitous, optional, unwanted behavior).
- **The decision log preserves context.** Every question asked and answered during requirements gathering is logged so that design and implementation can understand *why* decisions were made.
- **Terminology carries downstream.** The glossary established here should be used in design.md, stream plans, code (variable names, file names, API endpoints), and documentation.
- **The adversarial self-review catches blind spots.** Don't skip it — it's cheaper to find issues here than during implementation or review.
- **Users can add more context at any time.** If the user says "oh also..." or "I forgot to mention..." during any step, incorporate it and re-evaluate affected capabilities.
- **Use the Write tool for creating files, Edit tool for modifying files, and Read tool for reading files.** Only use Bash for git commands and directory creation.
- **Capability IDs (CAP-1, CAP-2, etc.) are referenced downstream.** Design.md maps capabilities to architecture components. Stream plans map to capabilities via the requirements mapping in plan.md.

---

## EARS Syntax Reference

See [references/ears-syntax.md](references/ears-syntax.md) for the full EARS pattern guide with examples.

## Analysis Patterns Reference

See [references/analysis-patterns.md](references/analysis-patterns.md) for common gap patterns, conflict types, and edge case categories.
