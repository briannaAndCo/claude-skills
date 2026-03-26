# Guiding Principles Reference

## What Makes a Good Principle

A guiding principle is a constraint that shapes every stream's implementation. It is the contract between the project-level design and stream-level planning.

### Qualities

1. **Enforceable** — Can be verified by reading code or running a check. "Code should be clean" is not enforceable. "All public functions have explicit return types" is.
2. **Architectural** — About structure, boundaries, and data flow. Not about style, formatting, or naming (those belong in Stack Guidelines).
3. **Stable** — Won't change when implementation details shift. "Use PostgreSQL" is a decision, not a principle. "All persistence goes through the repository layer" is a principle.
4. **Language-agnostic** — Expressible without referencing a specific API or framework method. Stack-specific implementation details go in the Stack Guidelines section.
5. **Finite** — 5-12 principles is the sweet spot. Fewer than 5 usually means the architecture isn't well-defined. More than 15 means principles are too granular.

### Anatomy

```markdown
### GP-1: <Statement in imperative mood>
- **Rationale**: <ties to a use case, architectural decision, or domain constraint>
- **Verification**: <how to mechanically check — what to grep, what to test, what pattern to look for>
- **Stack notes**: <how this principle manifests in the chosen stack, if applicable>
```

## Examples

### Good Principles

```markdown
### GP-1: All state mutations go through the event bus
- **Rationale**: Enables audit logging, undo, and real-time sync without coupling producers to consumers (UC-2, UC-5)
- **Verification**: No direct state writes outside event handlers. Grep for state assignment — every hit should be inside an event handler or reducer.

### GP-2: External service calls are isolated behind adapter interfaces
- **Rationale**: Allows testing without live services and makes provider swaps a single-file change (Technical Decision #3)
- **Verification**: No direct HTTP/SDK calls outside `adapters/` directory. Integration tests mock at the adapter boundary.

### GP-3: Each module exposes a single public entry point
- **Rationale**: Prevents deep coupling between modules and makes dependency graphs legible (Architecture: Components)
- **Verification**: Each module directory has exactly one `index` or `mod` file that re-exports the public API. No cross-module imports bypass this.

### GP-4: Error handling preserves the original context chain
- **Rationale**: Debugging production issues requires tracing errors back to their source (UC-7: Operator troubleshooting)
- **Verification**: Errors are wrapped, not replaced. Every catch/recover site adds context. No bare `throw new Error("failed")` without cause.

### GP-5: Data validation happens at system boundaries, not internally
- **Rationale**: Internal code trusts the types; validation at entry points catches bad data early without redundant checks (Architecture: Boundaries)
- **Verification**: Validation logic exists only in API handlers, CLI parsers, file readers, and deserialization layers. Internal functions do not re-validate their inputs.
```

### Anti-patterns

| Principle | Problem |
|-----------|---------|
| "Write clean, readable code" | Not enforceable — subjective |
| "Use React hooks" | Framework-specific — belongs in Stack Guidelines |
| "Functions should be short" | No clear threshold — not mechanically verifiable |
| "Follow SOLID principles" | Too abstract — which ones, applied how? |
| "Use PostgreSQL for storage" | A decision, not a principle — put in Technical Decisions |
| "Always write tests" | Too vague — what kind, what coverage, for what? |

### Better Versions of Anti-patterns

| Anti-pattern | Better Principle |
|-------------|-----------------|
| "Write clean code" | "Each function does one thing and its name describes what" |
| "Use React hooks" | (Stack Guideline, not a principle) |
| "Functions should be short" | "Functions with more than one level of abstraction are split" |
| "Follow SOLID" | "Dependencies point inward — domain code never imports infrastructure" |
| "Use PostgreSQL" | (Technical Decision, not a principle) |
| "Always write tests" | "Every public behavior has at least one test that exercises it end-to-end" |

## How Principles Flow Downstream

```
design.md (GP-1, GP-2, ..., GP-N)
    │
    ├── stream-plan reads principles
    │   ├── Lists applicable GPs
    │   ├── Maps each to concrete approach
    │   └── Quality checklist includes GP compliance
    │
    └── review-stream verifies principles
        ├── Quality agent checks GP compliance
        └── Flags violations with GP ID and evidence
```

If a stream plan reveals that a principle is wrong, too restrictive, or missing a case:
1. Surface it to the user during stream planning
2. If the user agrees, update `design.md` on meta **before** finalizing the stream plan
3. Document the change in the principle's rationale
