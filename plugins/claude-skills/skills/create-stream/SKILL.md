---
name: create-stream
description: This skill should be used when the user asks to "create a stream", "new stream", "add a stream", "add stream to project", "create a thread", or wants to add a new stream to an existing project. Creates a new stream on the project's meta branch with planning files and updates the streams table.
version: 1.0.0
---

# Create Stream

Adds a new stream to an existing project. Creates the stream's planning files on the meta branch, updates the project's streams table, and optionally opens the stream via `open-stream`.

---

## Flow

### 1. Resolve the Project

Determine which project the stream belongs to. Run in parallel:

```bash
cat ~/.claude/projects-registry.json 2>/dev/null
```

```bash
git rev-parse --show-toplevel 2>/dev/null
```

**Resolution order:**
1. If the user specified a project name, match against `projects[].name` in the registry
2. If inside a git repo, check if that repo is registered
3. If ambiguous or no match, show registered projects and ask

Extract `path` and `metaBranch` for the matched project.

If no projects are registered, tell the user to create one first with the `create-project` skill.

### 2. Gather Stream Details

Ask conversationally — one question at a time:

1. **Stream name** (required) — convert to kebab-case
2. **Brief description** (required) — one sentence, used in the streams table Notes column
3. **Objective** (optional) — longer description for the stream's plan.md. If not provided, use the brief description.
4. **Blocked by** (optional) — names of other streams this depends on

### 3. Read Current Project State

```bash
git -C <repo-path> show <meta-branch>:plan.md
```

Verify the stream name doesn't already exist in the streams table. If it does, warn and ask the user to pick a different name or confirm they want to overwrite.

### 4. Write Stream Files to Meta Branch

Switch to the meta branch safely:

```bash
cd <repo-path>
git stash --include-untracked 2>/dev/null || true
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
git checkout <meta-branch>
```

Create the stream directory:

```bash
mkdir -p streams/<stream>/
```

Use the **Write tool** to create:

#### `streams/<stream>/plan.md`

```markdown
# Plan: <stream-name>
> Type: <feature|bug|refactor|research|ops|docs>

## Objective
<objective or brief description>

## Tasks
- [ ] (to be defined during stream planning)

## Acceptance Criteria
- (to be defined during stream planning)

## Notes
<any initial context>
```

#### `streams/<stream>/session.md`

```markdown
# Sessions: <stream-name>
```

#### `streams/<stream>/hours.md`

```markdown
# Hours: <stream-name>

| Date | Duration | Notes |
|------|----------|-------|

**Total**: 0h 00m
```

### 5. Update the Streams Table and project.json

Use the **Edit tool** to add a row to the streams table in `plan.md`. Include the Type column:

- Status: `blocked` if blockers were specified, `unblocked` otherwise
- Type: `feature` (default), `bug`, `refactor`, `research`, `ops`, or `docs` — ask the user
- Blocked By: comma-separated list of blocker stream names, or `—`
- Notes: the brief description

Also use the **Read tool** to read `project.json`, then use the **Write tool** to update it with the new stream entry:

```json
"<stream-name>": {
  "status": "unblocked",
  "type": "<type>",
  "blockedBy": [],
  "description": "<brief description>"
}
```

### 6. Commit and Return

```bash
git add streams/<stream>/ plan.md project.json
git commit -m "meta: add stream <stream>"
git checkout "$CURRENT_BRANCH" 2>/dev/null || git checkout main
git stash pop 2>/dev/null || true
```

### 7. Confirm and Offer to Open

Tell the user:
- Stream `<stream>` created on `<meta-branch>`
- Status: `unblocked` or `blocked` (with blockers listed)
- Files created: plan.md, session.md, hours.md

Then ask: "Want to open this stream now?"

If yes, invoke the `open-stream` skill with the project path and stream name.

---

## Important Notes

- **Use the Write tool for creating files, Edit tool for modifying files, Read tool for reading.** Only use Bash for git commands and directory creation.
- Stream names must be kebab-case and unique within the project.
- The description should be concise — it appears in the streams table Notes column and in the tmux status bar.
- Always stash before switching to the meta branch and pop after returning.
- If the user provides initial tasks or AC, include them in the stream plan.md instead of the placeholder text.
