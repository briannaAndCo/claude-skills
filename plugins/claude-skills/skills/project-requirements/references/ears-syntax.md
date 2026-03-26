# EARS Syntax Reference

EARS (Easy Approach to Requirements Syntax) was developed by Alistair Mavin at Rolls-Royce to eliminate vague, ambiguous requirements. It provides five sentence patterns that cover all requirement types.

## The Five Patterns

### 1. Ubiquitous — always true, no trigger needed

**Pattern**: `The <system> shall <response>.`

**Use when**: The requirement is always active — a fundamental property of the system.

**Examples**:
- The system shall store all data in UTF-8 encoding.
- The system shall log every API request with timestamp, actor, and action.
- The system shall enforce unique constraints on email addresses.

**Watch out for**: Requirements that seem ubiquitous but actually depend on a state or trigger. "The system shall display the user's name" — where? when? This is probably event-driven ("When a user opens their profile...").

---

### 2. Event-driven — in response to a trigger

**Pattern**: `When <trigger>, the <system> shall <response>.`

**Use when**: Something happens and the system reacts.

**Examples**:
- When a user submits the login form, the system shall validate credentials against the auth provider.
- When a file upload exceeds 10MB, the system shall reject the upload with a size limit error.
- When a stream status changes to complete, the system shall check and unblock dependent streams.

**Watch out for**: Missing the trigger. "The system shall send a notification" — when? What triggers it?

---

### 3. State-driven — while a condition holds

**Pattern**: `While <state>, the <system> shall <response>.`

**Use when**: The system behaves differently depending on its current state.

**Examples**:
- While the system is in maintenance mode, the system shall return a 503 status to all API requests.
- While a user session is active, the system shall refresh the auth token every 15 minutes.
- While a stream is in-progress, the system shall prevent deletion of its worktree.

**Watch out for**: Confusing state-driven with event-driven. "While the user clicks the button" is wrong — clicking is an event, not a state. Use "When the user clicks the button."

---

### 4. Optional feature — configurable behavior

**Pattern**: `Where <feature is enabled/configured>, the <system> shall <response>.`

**Use when**: The behavior depends on a configuration setting, feature flag, or optional component.

**Examples**:
- Where a GitHub remote is configured, the system shall push planning state to the meta branch after updates.
- Where email notifications are enabled, the system shall send a summary after each session.
- Where the project has a `.editorconfig`, the system shall apply its formatting rules.

**Watch out for**: Using "where" for conditions that aren't really optional features. "Where the user is an admin" is a state or role, not an optional feature — use state-driven or add it as a precondition to an event-driven requirement.

---

### 5. Unwanted behavior — error and edge case handling

**Pattern**: `If <condition>, then the <system> shall <response>.`

**Use when**: Defining how the system handles errors, invalid inputs, or exceptional conditions.

**Examples**:
- If the database connection is lost, then the system shall retry 3 times with exponential backoff before surfacing an error.
- If a user provides a stream name that already exists, then the system shall warn the user and ask for confirmation before overwriting.
- If the meta branch does not exist, then the system shall create an orphan meta branch.

**Watch out for**: Using if/then for normal behavior. "If the user clicks save, then the system shall save the document" — this is normal behavior, use event-driven: "When the user clicks save..."

---

## Compound Patterns

Patterns can be combined for precision:

**Event + State**: `While <state>, when <trigger>, the <system> shall <response>.`
- While the system is online, when a user submits a form, the system shall process it synchronously.

**Event + Unwanted**: `When <trigger>, if <error condition>, then the <system> shall <response>.`
- When a user uploads a file, if the file type is not in the allowed list, then the system shall reject the upload with a descriptive error.

**Optional + Event**: `Where <feature>, when <trigger>, the <system> shall <response>.`
- Where audit logging is enabled, when a user modifies a record, the system shall write an audit entry with before/after values.

---

## Writing Good EARS Requirements

### Do
- Use one requirement per statement (don't chain with "and")
- Use measurable, specific responses ("return a 400 status with field-level errors" not "handle gracefully")
- Include the actor or trigger explicitly
- Use domain terminology from the project glossary

### Don't
- Use vague verbs: "handle", "manage", "process", "support" — what does it actually *do*?
- Use subjective qualities: "quickly", "user-friendly", "secure" — how do you test that?
- Mix multiple requirements in one statement
- Use passive voice without identifying the system: "The data should be validated" — by what?

### Converting Vague Requirements

| Vague | EARS |
|-------|------|
| "The system should handle errors gracefully" | If a database query fails, then the system shall return a 500 status with a correlation ID and log the error with full stack trace. |
| "Users can upload files" | When a user selects a file and clicks upload, the system shall validate the file type, check the size limit, and store the file in the configured storage backend. |
| "The system should be fast" | When a user requests the dashboard, the system shall return the response within 200ms at the 95th percentile under normal load. |
| "Support notifications" | When a stream status changes to complete, the system shall notify all users subscribed to that stream via their configured notification channel. |

---

## Mapping EARS to Acceptance Criteria

Each EARS requirement should have at least one Given-When-Then acceptance criterion:

**Requirement**: When a user submits the login form, the system shall validate credentials against the auth provider.

**Acceptance Criteria**:
- Given valid credentials, when the user submits the login form, then the system returns a session token
- Given invalid credentials, when the user submits the login form, then the system returns a 401 with "Invalid credentials"
- Given the auth provider is unreachable, when the user submits the login form, then the system returns a 503 with "Authentication service unavailable"

The EARS pattern tells you *what* the requirement is. The AC tells you *how to verify* it.
