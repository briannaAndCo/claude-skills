---
name: open-project
description: This skill should be used when the user asks to "open project", "open [project-name]", "show project", "show streams", "project status", "what's the status of [project]", "switch to project", or wants to see a project's streams and their status. Opens a project by displaying its objective, a streams table with status and descriptions, and lets the user open one or more streams (delegating to the `open-stream` skill).
version: 1.0.0
---

# Open Project

Opens a project by displaying its objective and a full streams overview with status, descriptions, and blockers. The user can then select one or more streams to open — each is delegated to the `open-stream` skill.

---

## Flow

### 1. Resolve the Project

Determine which project the user means. Run in parallel:

```bash
cat ~/.claude/projects-registry.json 2>/dev/null
```

```bash
git rev-parse --show-toplevel 2>/dev/null
```

**Resolution order:**
1. If the user said a project name (e.g., "open braindump-notes"), match it against the registry's `projects[].name`
2. If the user just said "open project" with no name, check if the current directory is inside a registered project's repo path
3. If multiple matches or no match, show all registered projects as a numbered list and ask:

```
Projects:
  1. braindump-notes — Mobile-first note-taking app
  2. my-api          — REST API backend

Enter a number:
```

To build that list, for each registry entry read the objective:

```bash
git -C <path> show <metaBranch>:plan.md 2>/dev/null | sed -n '/^## Objective$/,/^##/{ /^##/!p; }' | head -1
```

If no projects are registered, tell the user: "No projects found. Use the `create-project` skill to set up one."

### 2. Read Project State

Once the project is resolved, read the plan from the meta branch:

```bash
git -C <repo-path> show <meta-branch>:plan.md
```

Extract:
- **Project name** — first `#` heading
- **Objective** — content under `## Objective` until the next `##`
- **Streams table** — the markdown table under `## Streams`

### 3. Display the Project Overview

Present the project in this format:

```
# <project-name>
<objective — 1-3 lines>

| #  | Stream                  | Status      | Description                         | Blocked By               |
|----|-------------------------|-------------|-------------------------------------|--------------------------|
| 1  | auth-middleware         | ● active    | JWT validation and session mgmt     | —                        |
| 2  | api-routes              | ○ ready     | REST endpoints for notes CRUD       | —                        |
| 3  | db-schema               | ○ ready     | SQLite schema and migrations        | —                        |
| 4  | notification-system     | ✕ blocked   | Push notification service           | auth-middleware, api-routes |
| 5  | dashboard-ui            | ◌ planned   | Main dashboard view                 | —                        |
| 6  | settings-page           | ✓ complete  | User preferences screen             | —                        |

Enter stream numbers to open (e.g. "1", "1 2 3"), or:
  a — Open all actionable streams (active + ready)
  n — Create a new stream
```

**Status indicators** (map from raw status):

| Status      | Indicator      |
|-------------|----------------|
| in-progress | `● active`     |
| unblocked   | `○ ready`      |
| blocked     | `✕ blocked`    |
| complete    | `✓ complete`   |
| planned     | `◌ planned`    |
| on-hold     | `⏸ on-hold`   |

**Description** comes from the `Notes` column in the plan.md streams table. If the Notes column is empty, read the stream's plan.md from meta and use the first line of its objective:

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/plan.md 2>/dev/null | sed -n '/^## Objective$/,/^##/{ /^##/!p; }' | head -1
```

### 4. Handle User Selection

Wait for the user's input:

#### Single stream: `"1"` or `"auth-middleware"`

Invoke the `open-stream` skill with the project path and selected stream name.

#### Multiple streams: `"1 2 3"` or `"auth-middleware api-routes db-schema"`

Invoke the `open-stream` skill for each selected stream sequentially, with a brief pause between launches. Confirm each one as it opens:

```
Opening auth-middleware... ✓
Opening api-routes... ✓
Opening db-schema... ✓

3 streams opened in parallel.
```

#### All actionable: `"a"`

Collect all streams with status `in-progress` or `unblocked`. Invoke `open-stream` for each.

#### New stream: `"n"`

Delegate to the `create-stream` skill, passing the resolved project path and meta branch. After creation, `create-stream` will offer to open the new stream via `open-stream`.

---

## Edge Cases

- **No streams exist yet**: Skip the table, show the objective, and offer to create streams or run project decomposition.
- **All streams complete**: Show the table, congratulate, and note that no actionable streams remain.
- **Blocked streams selected**: Warn the user that the stream is blocked and ask if they want to open it anyway. If yes, proceed via `open-stream`.
- **Stream already running** (tmux session exists): `open-stream` handles reconnection — it will attach to the existing session.

---

## Important Notes

- **This skill is the primary "open project" entry point.** The `project-manager` skill should delegate here when the user selects a project to open.
- **All stream opening is delegated to `open-stream`.** Do not duplicate worktree, tmux, or CLAUDE.md logic here.
- **Use Read tool for files, Write tool for creating, Edit tool for modifying.** Only use Bash for git commands.
- **Status mapping uses visual indicators** — never show raw status strings like `in-progress` in the table. Always use the indicator column format (`● active`, `○ ready`, etc.).
- Numbers in the table should be sequential across all streams (not just actionable ones) so the user can reference any stream by number.
