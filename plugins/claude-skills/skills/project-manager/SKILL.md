---
name: project-manager
description: This skill should be used when the user asks to "open projects", "manage projects", "new project", "create project", "open a stream", "start a session", "log time", "track time", "project manager", "what projects do I have", "show my projects", "open tmux", "start parallel streams", "run streams in parallel", "set up tmux for project", "work on multiple streams", or mentions working on an epic, story, ticket, or stream. Manages structured project and stream workspaces with session tracking, time logging, and tmux-based parallel Claude instances.
version: 1.2.0
disable-model-invocation: true
---

# Project Manager

Manages a structured workspace of projects (epics) and streams (stories/tickets) with session logging and time tracking.

## Environment Assumption

**Claude is always running inside a tmux session.** The user launches Claude via the `ct` alias (`tmux new-session -A -s claude`) or the `pt` alias (`project-tmux`). This means:

- When opening a stream, always offer to open it in a **new tmux window** in the current session
- When the user wants parallel work, open multiple tmux windows — one per stream — each with its own Claude instance
- Never suggest running `tmux` as an optional step; it is the default environment
- Use `pt` as the shorthand for `project-tmux` in all examples

---

## Configuration

Check for a config file at `~/.claude-projects-config`:

```json
{
  "projects_root": "~/projects",
  "repos": {
    "<project-name>": "git@github.com:<org>/<repo>.git"
  }
}
```

If it doesn't exist, use `~/projects` as the default root. If the user specifies a different location, create or update the config file.

The `repos` map is optional. When present, the project's tracking files are synced to a `meta` branch on that remote after every significant update (see [Tracking Branch](#tracking-branch)).

---

## Entry Point: Opening the Projects Workspace

When the skill is invoked:

1. Read the config to get `projects_root`
2. List all directories inside `projects_root` (each is a project)
3. Present the user with:
   - A list of existing projects (name + brief status from `plan.md` if available)
   - Option to **create a new project**

Ask:
> "Which project would you like to work on, or would you like to create a new one?"

---

## Creating a New Project

1. Ask for the project name (convert to kebab-case for the folder)
2. Ask for a brief description / objective
3. Ask for initial planned streams (optional — can be added later)
4. Ask for an optional GitHub repo URL (for tracking branch sync — can be added later)
5. Create the project structure (see [File Structure](#file-structure))
6. Populate `plan.md` with the objective, planned streams, and empty dependency/status table
7. If a repo URL was provided, add it to `~/.claude-projects-config` under `repos`
8. Confirm creation, then offer to open it in tmux: `pt open <project-name>`

---

## Opening a Project

1. Read the project's `plan.md` from the meta branch using Bash: `git show meta:plan.md`
2. Display the project objective
3. Parse the streams table and present **actionable streams** — those with status `in-progress` or `unblocked` — as a numbered list with brief summaries:

```
Ready to work on:

  1. auth-middleware (in-progress) — JWT validation and session management
  2. api-routes (unblocked) — REST endpoints for user and project resources
  3. db-schema (unblocked) — SQLite migrations for core data model

Other streams:
  • notification-system (blocked by auth-middleware, api-routes)
  • dashboard-ui (planned)
  • settings-page (complete)

Enter a number to open a stream, or:
  n  Create a new stream
  p  Open parallel streams
  t  View project tasks/hours
```

4. Wait for user input:
   - **Number** → open that stream (triggers Phase 5/6 from the project lifecycle — stream design if not yet designed, or implementation if already approved)
   - **n** → create a new stream
   - **p** → prompt for which unblocked/in-progress streams to open in parallel
   - **t** → show project-level tasks and hours summary

5. If no streams exist yet, skip the numbered list and offer to create one or run the decompose phase

---

## Creating a New Stream

1. Ask for the stream name (kebab-case for folder)
2. Ask for objective / scope
3. Ask which streams (if any) this stream is blocked by
4. Create the stream directory with `plan.md`, `session.md`, `hours.md`
5. Update the project's `plan.md` to add the new stream with `planned` status and its dependencies
6. Offer to open it immediately: `pt stream <project-name> <stream-name>`

---

## Opening a Stream

Opening a stream always means opening it in a new tmux window with its own Claude instance:

```bash
pt stream <project-name> <stream-name>
```

This:
1. Writes a `CLAUDE.md` into the stream directory with project/stream context
2. Opens a new tmux window named after the stream (colored uniquely in the status bar)
3. Starts `claude` in that window — reads `CLAUDE.md` automatically on launch

The Claude instance in that window is independent. The user switches to it with `Prefix + <window-number>`.

Once inside a stream window, that Claude instance should:
1. Display the stream's `plan.md` (objective, tasks, acceptance criteria)
2. Show recent sessions from `session.md` and total from `hours.md`
3. Ask what the user wants to do:
   - **Start a session**
   - **Log time manually**
   - **Update the plan**
   - **Mark stream complete**

---

## Running Parallel Streams

When the user wants to work on multiple streams simultaneously:

1. Read `plan.md` and identify which streams are `unblocked` or `in-progress`
2. Present the unblocked streams and suggest a parallel grouping based on the dependency map
3. Open them all at once:

```bash
pt parallel <project-name> <stream1> <stream2> <stream3> ...
```

Each stream gets its own colored tmux window and independent Claude instance. The user switches between them with `Prefix + <number>`.

**Example — Wave 4 of continuous-notebook:**
```bash
pt parallel braindump-notes \
  auto-append inline-editing paginated-scroll \
  background-sync color-rotation hand-drawn-rendering
```

---

## Session Management

### Starting a Session

Record the start time in the stream's `session.md`:

```markdown
## Session: YYYY-MM-DD HH:MM
- **Status**: in-progress
```

Also update the project-level `session.md` with the same entry.

### Ending a Session

When the user signals they're done (says "end session", "stop session", "done for now", "wrapping up", "save session"):

1. Record end time
2. Calculate duration — **round to nearest 15 minutes**
3. Ask what was accomplished (brief notes)
4. Append completed session to stream `session.md`
5. Append an entry to stream `hours.md`
6. Append an entry to project-level `tasks.md`
7. Update the project-level `session.md`
8. Push to the `meta` branch (see [Tracking Branch](#tracking-branch))

---

## Time Tracking Rules

See [references/time-tracking.md](references/time-tracking.md) for rounding rules and format.

- All durations rounded to nearest **15-minute increment**
- Format: `Xh Ym` (e.g., `1h 30m`, `0h 45m`, `2h 00m`)
- Minimum logged: `0h 15m`

---

## File Structure

```
<projects-root>/
└── <project-name>/
    ├── plan.md            # Master plan: objective, streams, dependencies, statuses
    ├── session.md         # Project-level session log (all streams combined)
    ├── tasks.md           # All tasks logged across streams with time
    └── streams/
        └── <stream-name>/
            ├── CLAUDE.md  # Auto-generated context for Claude on window open
            ├── plan.md    # Stream scope, tasks checklist, acceptance criteria
            ├── session.md # Stream-level session log
            └── hours.md   # Time entries for this stream
```

See [references/file-formats.md](references/file-formats.md) for exact file formats.

---

## tmux Quick Reference

```bash
pt open     <project>               # open project overview window
pt stream   <project> <stream>      # open stream in new window with Claude
pt parallel <project> <s1> <s2>...  # open parallel streams
pt attach   <project>               # reconnect to a session
pt list                             # list active project sessions
pt kill     <project>               # end a session
```

See [references/tmux-setup.md](references/tmux-setup.md) for status bar config and tips.

---

## Updating Stream Status

When a stream status changes for any significant reason (started, completed, blocked, unblocked), update the project `plan.md`:
- Change status to the new value
- When marking `complete`: check if any other streams were blocked by this one and update their status to `unblocked` if all blockers are now resolved
- After updating, push to the `meta` branch (see [Tracking Branch](#tracking-branch))

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`

---

## Tracking Branch

The `meta` branch in the project's GitHub repo stores the planning state — `plan.md` and all stream files. It is the source of truth for project context across machines and sessions. The `meta` branch contains **only planning/tracking files** — no source code.

### When to Push

Push to `meta` after any of:
- Stream status change (`planned` → `in-progress`, `in-progress` → `complete`, etc.)
- Session end (session.md and hours.md updated)
- Plan updated (tasks checked off, acceptance criteria changed)
- New stream created

### How to Push

1. Look up the repo URL for this project in `~/.claude-projects-config` under `repos`
2. If no URL is configured, skip silently
3. Set up a temporary clone or use the project's worktree if available:

```bash
# From a temp dir — clone sparse, meta branch only
TMPDIR=$(mktemp -d)
git clone --depth 1 --branch meta --no-checkout <repo-url> "$TMPDIR/meta-repo" 2>/dev/null \
  || git clone --depth 1 --no-checkout <repo-url> "$TMPDIR/meta-repo"

cd "$TMPDIR/meta-repo"

# If meta branch doesn't exist yet, create orphan
git checkout meta 2>/dev/null || git checkout --orphan meta

# Wipe the branch content and replace with current planning files
git rm -rf . --quiet 2>/dev/null || true

# Copy planning files
cp <projects-root>/<project-name>/plan.md .
cp -r <projects-root>/<project-name>/streams ./streams

# Commit and push
git add -A
git commit -m "meta: update tracking — <brief description of what changed>"
git push origin meta

# Clean up
rm -rf "$TMPDIR"
```

4. Inform the user: `"Pushed planning state to meta branch."`

### Initial Setup

When a repo is first configured for a project:
1. Create the orphan `meta` branch with the current planning state
2. Push it — this is the baseline

Non-planning files (source code, `.claudeignore`, configs) live only on `main` and feature branches, never on `meta`. Planning files (plan.md, session.md, hours.md, stream plans) live only on `meta`, never committed to `main`.
