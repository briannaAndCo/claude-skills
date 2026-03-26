# Analysis Patterns Reference

Common patterns for the three expert analysis agents to look for during requirements gathering.

---

## Gap Patterns (Agent 1)

### Functional Gaps

| Pattern | Description | Example |
|---------|-------------|---------|
| **Missing CRUD** | Create/Read mentioned but Update/Delete missing | "Users can create projects" — but can they delete them? |
| **Missing error path** | Happy path described, failure path absent | "User uploads a file" — what if the upload fails midway? |
| **Missing actor** | Capability described without specifying who can do it | "Reports can be exported" — by whom? All users? Admins only? |
| **Missing trigger** | Behavior described without specifying when it happens | "The system sends notifications" — triggered by what? |
| **Orphan reference** | Refers to a concept that's never defined | "Uses the standard workflow" — what standard workflow? |

### Non-Functional Gaps

| Pattern | Description | Question to Ask |
|---------|-------------|-----------------|
| **No performance target** | User-facing operations with no latency/throughput requirements | "How fast should [operation] be?" |
| **No data retention** | Data is created but lifecycle is undefined | "How long is [data] kept? Who deletes it?" |
| **No concurrency model** | Multi-user scenarios without conflict resolution | "What happens when two users edit the same [thing] simultaneously?" |
| **No security boundary** | Sensitive operations without access control | "Who is allowed to [operation]? How is that enforced?" |
| **No migration path** | New behavior with no plan for existing data/users | "What happens to existing [data] when this ships?" |

---

## Conflict & Ambiguity Patterns (Agent 2)

### Contradiction Types

| Type | Description | Example |
|------|-------------|---------|
| **Direct contradiction** | Two statements that can't both be true | Doc A: "All users can export." Doc B: "Only admins can export." |
| **Scope contradiction** | One place says in-scope, another says out-of-scope | Requirements say "MVP includes search." Constraints say "Search is post-v1." |
| **Priority contradiction** | Conflicting priority signals | "Performance is critical" but "Use the simplest possible implementation." |
| **Temporal contradiction** | Different timelines for the same deliverable | "Launch by Q2" in one place, "After the auth rewrite" in another (which is Q3). |

### Ambiguity Types

| Type | Description | Example |
|------|-------------|---------|
| **Polysemous term** | Same word, different meanings in different contexts | "Record" means a database row in one place, an audio recording in another. |
| **Vague quantifier** | "Some", "many", "few", "large", "quickly" | "The system should handle large files" — how large? |
| **Implicit assumption** | Assumes knowledge the reader might not have | "Uses the standard auth flow" — which standard? OAuth2? SAML? Custom? |
| **Dangling pronoun** | "It", "they", "this" without clear referent | "When the user submits the form, it validates the data" — the form or the system? |
| **Boundary ambiguity** | Unclear where one capability ends and another begins | "The system handles user management and permissions" — one capability or two? |

### Resolution Strategies

For each conflict or ambiguity:
1. **Quote both sources** — show the user the exact passages
2. **Explain the impact** — what goes wrong if we pick the wrong interpretation
3. **Offer a recommendation** — which interpretation seems more consistent with the overall vision
4. **Record the decision** — once resolved, log it in the Decision Log with rationale

---

## Edge Case Categories (Agent 3)

### Input Edge Cases

| Category | Cases to Check |
|----------|---------------|
| **Empty/null** | No input, empty string, null value, whitespace-only |
| **Boundary values** | Zero, one, max, max+1, negative, very large |
| **Invalid format** | Wrong type, wrong encoding, malformed structure |
| **Injection** | SQL injection, XSS, command injection, path traversal |
| **Unicode** | Emoji, RTL text, zero-width characters, combining characters |
| **Duplicate** | Same input submitted twice, idempotency |

### State Edge Cases

| Category | Cases to Check |
|----------|---------------|
| **First use** | No data exists yet, no configuration, no history |
| **Empty collection** | List/table/feed with zero items |
| **Single item** | Collection with exactly one item (pluralization, pagination) |
| **Full/at limit** | Storage full, rate limit reached, quota exhausted |
| **Stale state** | Data changed between read and write, cache invalidation |

### Concurrency Edge Cases

| Category | Cases to Check |
|----------|---------------|
| **Simultaneous writes** | Two users edit the same resource |
| **Read-during-write** | User reads while another writes |
| **Race condition** | Order-dependent operations happening out of order |
| **Partial failure** | Multi-step operation fails midway |
| **Timeout** | Long-running operation exceeds time limit |

### Access Edge Cases

| Category | Cases to Check |
|----------|---------------|
| **No permission** | User lacks required role/permission |
| **Expired session** | Auth token expired during operation |
| **Revoked access** | Permission removed while user is active |
| **Deleted resource** | Accessing something that was just deleted |
| **Cross-tenant** | Accessing another user's/org's data |

### Data Edge Cases

| Category | Cases to Check |
|----------|---------------|
| **Referential integrity** | Delete a record that others reference |
| **Circular reference** | A depends on B depends on A |
| **Orphaned records** | Parent deleted, children remain |
| **Data migration** | Old format encounters new code (or vice versa) |
| **Large payload** | Response too large to serialize/transmit efficiently |

---

## Using These Patterns

The three expert agents use these patterns as checklists during analysis:

1. **Gap Analyst** scans source material against the gap patterns. For each gap found, assess severity:
   - **Critical**: Missing gap makes the system non-functional or insecure
   - **Important**: Missing gap will cause problems during implementation or review
   - **Nice-to-have**: Missing gap is a refinement, not a blocker

2. **Conflict & Ambiguity Detector** scans for contradiction and ambiguity types. For each found, quote the conflicting/ambiguous passages directly from source material.

3. **Edge Case & Risk Scanner** runs through edge case categories for each capability. Not every category applies to every capability — use judgment. Focus on categories that match the capability's domain (e.g., concurrency edge cases for shared resources, input edge cases for user-facing forms).
