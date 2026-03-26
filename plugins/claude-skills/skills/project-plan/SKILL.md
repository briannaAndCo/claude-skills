---
name: project-plan
description: High-level project planning — architecture, use cases, workflows, design, and guiding principles. Called during project setup (after requirements) or invoked directly. Produces design.md on the meta branch with enforceable guiding principles that stream plans must adhere to.
version: 1.0.0
---

# Project Plan

Produces a high-level design for a project: architecture, use cases, workflows, and — critically — a set of **guiding principles** that all stream-level plans and reviews must follow. Language-agnostic by default, with optional stack-specific refinements.

**Output on meta branch (`meta/<project-slug>`):** `design.md`

---

## Flow

### Step 1: Read Context

Use Bash to read existing planning state from meta:

```bash
cd <repo-path>
git show meta/<project-slug>:requirements.md 2>/dev/null || true
git show meta/<project-slug>:plan.md
```

If the repo has existing code, launch 2-3 **Explore agents** in parallel to:
- Map existing architecture, patterns, and conventions
- Identify types, interfaces, abstractions, and module boundaries
- Find test patterns, CI/CD configuration, and build setup
- Detect the language/framework stack in use (if any)
- **Find all documentation**: `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/` directory, ADRs, inline doc comments, config files that encode conventions (linter configs, `.editorconfig`, etc.)
- Read and summarize all discovered documentation — this is the project's stated intent

### Step 2: Use Cases & Workflows

Discuss with the user conversationally. **Ask one question at a time** — do not batch multiple questions into a single message. Ask, wait for the answer, incorporate it, then ask the next.

Walk through these areas in order:

1. **Actors** — "Who or what interacts with this system?" (users, services, cron jobs, external APIs)
2. **Use cases** — For each actor, "What are the key interactions?" Walk through one use case at a time.
3. **Workflows** — "How do these use cases chain together?" Trace end-to-end flows one at a time.
4. **Boundaries** — "Where does this system end and external systems begin?"

Capture each use case as:
- **Actor**: who initiates
- **Goal**: what they're trying to accomplish
- **Flow**: numbered steps through the system
- **Failure modes**: what can go wrong and how the system responds

**Wait for user confirmation on the full set before proceeding.**

### Step 3: Architecture

Propose the architecture:

1. **Components** — Major building blocks and their responsibilities
2. **Boundaries** — How components communicate (sync/async, protocols, data formats)
3. **Data model** — Entities, relationships, storage approach
4. **Data flow** — How data moves through the system for each primary use case
5. **API surface** — External interfaces (REST, CLI, events, file I/O — whatever applies)

Present this to the user **one component at a time**. For each component, confirm the user agrees with the responsibility and boundary before moving to the next.

If multiple viable architectures exist, present options **one at a time** with:
- **Option**: brief description
- **Tradeoffs**: complexity, flexibility, performance, testability
- **Recommendation**: which and why

**Get the user's decision before proceeding.**

### Step 4: Guiding Principles

This is the critical step. Derive a numbered set of **guiding principles** from the architecture and use cases. These are the rules that every stream must follow.

Launch an **Agent** to search the web for domain-relevant best practices:
- Search for architectural patterns relevant to the system type (e.g., "event-driven architecture principles", "CLI tool design principles", "CRUD API design principles")
- Search for data modeling best practices relevant to the domain
- Do NOT search for language-specific patterns — keep principles language-agnostic
- Filter results through the project's specific architecture decisions

Combine research with the architectural decisions to produce principles. Each principle gets:

- **ID** — `GP-<number>` (e.g., `GP-1`, `GP-2`)
- **Statement** — one sentence, imperative mood ("All state mutations go through the event bus")
- **Rationale** — why this principle exists (ties back to a use case, architectural decision, or best practice)
- **Verification** — how to mechanically check compliance (what to grep for, what patterns to look for, what to test)

Guidelines for good principles:
- **Enforceable** — can be verified by reading code, not by subjective judgment
- **Architectural** — about structure and boundaries, not style or formatting
- **Stable** — won't change with implementation details
- **Language-agnostic** — no framework-specific API calls (unless the project has committed to a stack)
- **Finite** — aim for 5-12 principles. More than 15 is a smell.

Present principles to the user **one at a time**. For each principle, present it and ask:
- "Does this capture the intent?"
- "Should the verification be more specific?"
- "Is this too restrictive or not restrictive enough?"

Wait for the user's response before presenting the next principle. Incorporate any feedback immediately.

**Do not proceed until the user approves the full set.**

### Step 5: Language & Stack Guidelines

This step is **always performed** — it is not optional. Even for greenfield projects, the user must confirm or choose a stack before proceeding.

#### 5a. Discover Existing Conventions

If the repo has existing code, launch **Explore agents** in parallel to:
- Find documentation files: `README.md`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `docs/`, `ADR/`, `.editorconfig`, linter configs, `tsconfig.json`, `Cargo.toml`, `pyproject.toml`, etc.
- Read all discovered docs — these represent the project's stated conventions
- Analyze code structure: directory layout, module organization, naming patterns, import style, error handling patterns, test organization
- Identify the **actual conventions** the code follows (which may differ from docs)

#### 5b. Surface Discrepancies

Compare documented conventions against actual code patterns. If they differ, present each discrepancy to the user:

- **Convention**: what the docs say (or what is industry-standard for the stack)
- **Actual**: what the code does
- **Impact**: does this matter for the project's goals?
- **Recommendation**: align with docs, align with code, or define a new standard

**Wait for the user's direction on each discrepancy before proceeding.**

#### 5c. Research Stack Best Practices

Launch an **Agent** to search the web for current best practices for the project's stack:
- Language-level idioms and patterns
- Framework conventions and anti-patterns
- Ecosystem tooling (linters, formatters, test frameworks) that enforce conventions
- Common pitfalls for the specific stack combination

#### 5d. Define Stack Guidelines

Produce a set of **stack-specific guidelines** that complement the guiding principles:

- Each guideline references which guiding principle(s) it implements at the stack level
- Covers: naming conventions, module organization, error handling patterns, test structure, dependency management
- Incorporates existing project conventions (from docs or code) where they don't conflict with guiding principles
- Flags any stack idiom that conflicts with a guiding principle — present the conflict to the user for resolution

**Ask the user if any stack-specific guidelines should be promoted to full guiding principles.**

### Step 6: Technical Decisions

Surface any remaining decisions that have meaningful tradeoffs but aren't captured in the principles. Present each as:

- **Decision**: what needs to be decided
- **Options**: 2-3 concrete approaches
- **Tradeoffs**: pros/cons (performance, complexity, maintainability)
- **Recommendation**: which option and why

Walk through one at a time. **Get the user's call before proceeding.**

### Step 7: Commit

Commit to meta using a temporary worktree to avoid touching the user's working tree:

```bash
cd <repo-path>
git worktree add /tmp/meta-work meta/<project-slug>
```

Use the **Write tool** to create `design.md` in `/tmp/meta-work/`. Then:

```bash
cd /tmp/meta-work
git add design.md
git commit -m "meta: add project design and guiding principles"
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

## `design.md` Format

```markdown
# Design: <project-name>

## Use Cases

### UC-1: <Use Case Name>
- **Actor**: <who>
- **Goal**: <what>
- **Flow**:
  1. <step>
  2. <step>
  3. <step>
- **Failure modes**: <what can go wrong>

### UC-2: <Use Case Name>
...

## Architecture

### Overview
<high-level description — what kind of system this is and how it's structured>

### Components
<component descriptions — responsibilities, boundaries, interfaces>

### Data Model
<entities, relationships, storage approach>

### Data Flow
<how data moves through the system for primary use cases>

### API Surface
<external interfaces — whatever the system exposes>

## Guiding Principles

### GP-1: <Principle Statement>
- **Rationale**: <why>
- **Verification**: <how to check>
- **Stack notes**: <language/framework-specific guidance, if applicable>

### GP-2: <Principle Statement>
- **Rationale**: <why>
- **Verification**: <how to check>

...

## Stack Guidelines

### Stack: <language/framework>

#### Conventions
- <convention from existing docs/code or newly established>
- <convention>

#### Discrepancies Resolved
- <what differed between docs and code, and what was decided>

#### Guidelines
| ID | Guideline | Implements Principle |
|----|-----------|---------------------|
| SG-1 | <stack-specific guideline> | GP-1, GP-3 |
| SG-2 | <stack-specific guideline> | GP-5 |

#### Tooling
- Linter: <tool and config>
- Formatter: <tool and config>
- Test framework: <tool>

## Technical Decisions

### 1. <Decision Title>
- **Context**: <why this matters>
- **Decision**: <what was decided>
- **Alternatives considered**: <what else was evaluated>
- **Rationale**: <why this option>

## Risks
- <known risks and mitigation strategies>
```

---

## Important Notes

- **Guiding principles are the contract between project-plan and stream-plan.** Stream plans must reference applicable principles by ID and show how they comply.
- **The verify skill also checks against guiding principles.** The quality agent checks principle compliance alongside DRY/simplicity/conventions.
- **Principles are living.** If a stream plan reveals that a principle is wrong or too restrictive, update `design.md` on meta — don't silently ignore it.
- **Use the Write tool for creating files, Edit tool for modifying files, and Read tool for reading files.** Only use Bash for git commands and directory creation.
- **Keep principles language-agnostic.** Stack-specific guidance goes in "Stack notes" under each principle, not in the principle statement itself.

---

## Guiding Principles Reference

See [references/guiding-principles.md](references/guiding-principles.md) for examples and anti-patterns.
