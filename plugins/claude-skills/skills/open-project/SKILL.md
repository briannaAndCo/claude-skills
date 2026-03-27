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

Determine which project the user means using the shared scripts:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
```

**Resolution order:**
1. If the user said a project name (e.g., "open braindump-notes"), resolve it directly:
   ```bash
   source "$SCRIPTS/pm-resolve.sh" <project-name>
   # Sets: REPO_DIR, META_BRANCH
   ```
2. If the user just said "open project" with no name, try resolving from the current directory:
   ```bash
   source "$SCRIPTS/pm-resolve.sh"
   # Uses _pm_resolve_cwd — sets REPO_DIR, META_BRANCH if cwd is inside a registered project
   ```
3. If resolution fails (no name given and not inside a project), list all registered projects and ask:
   ```bash
   bash "$SCRIPTS/pm-list-projects.sh"
   ```
   This prints a formatted table with project numbers, names, and objectives. Present it and ask:
   ```
   Enter a number:
   ```
   Then resolve the selected project by name using `pm-resolve.sh`.

If no projects are registered, tell the user: "No projects found. Use the `create-project` skill to set up one."

### 2. Display the Project Overview

Once resolved, display the project using the status script:

```bash
bash "$SCRIPTS/pm-status.sh" <project-name>
```

This prints the project name, objective, and a formatted streams table with numbered rows, status indicators, types, descriptions, and blockers — ready to present directly to the user.

After the table, prompt:

```
Enter stream numbers to open (e.g. "1", "1 2 3"), or:
  a — Open all actionable streams (active + ready)
  n — Create a new stream
```

**Status indicators** (for reference — `pm-status.sh` handles the mapping):

| Status      | Indicator      |
|-------------|----------------|
| in-progress | `● active`     |
| unblocked   | `○ ready`      |
| blocked     | `✕ blocked`    |
| complete    | `✓ complete`   |
| planned     | `◌ planned`    |
| on-hold     | `⏸ on-hold`   |

### 3. Handle User Selection

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

## Script-First Operations

For displaying project status and stream lists, prefer the shared scripts over Claude parsing markdown:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
# Project overview with stream indicators:
bash "$SCRIPTS/pm-status.sh" <project>
# What's ready to work on:
bash "$SCRIPTS/pm-next.sh" <project>
# List all projects:
bash "$SCRIPTS/pm-list-projects.sh"
```

Use script output directly when presenting the streams table to the user. This is instant and costs zero tokens.

---

## Important Notes

- **This skill is the primary "open project" entry point.** The `project-manager` skill should delegate here when the user selects a project to open.
- **All stream opening is delegated to `open-stream`.** Do not duplicate worktree, tmux, or CLAUDE.md logic here.
- **Use Read tool for files, Write tool for creating, Edit tool for modifying.** Only use Bash for git commands and shared scripts.
- **Status mapping uses visual indicators** — never show raw status strings like `in-progress` in the table. Always use the indicator column format (`● active`, `○ ready`, etc.).
- Numbers in the table should be sequential across all streams (not just actionable ones) so the user can reference any stream by number.
- **Prefer `project.json`** over parsing `plan.md` when you need structured data (stream names, statuses, types, blockers).
