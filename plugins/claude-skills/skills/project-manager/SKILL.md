---
name: project-manager
description: This skill should be used when the user asks to "open projects", "manage projects", "new project", "create project", "open a stream", "start a session", "log time", "track time", "project manager", "what projects do I have", "show my projects", "open tmux", "start parallel streams", "run streams in parallel", "set up tmux for project", "work on multiple streams", or mentions working on an epic, story, ticket, or stream. Manages structured project and stream workspaces with session tracking, time logging, and tmux-based parallel Claude instances.
version: 1.1.0
disable-model-invocation: true
---

# Project Manager

Manages a structured workspace of projects (epics) and streams (stories/tickets) with session logging and time tracking.

## Configuration

Check for a config file at `~/.claude-projects-config`:

```json
{
  "projects_root": "~/projects"
}
```

If it doesn't exist, use `~/projects` as the default root. If the user specifies a different location, create or update the config file.

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
4. Create the project structure (see [File Structure](#file-structure))
5. Populate `plan.md` with the objective, planned streams, and empty dependency/status table
6. Confirm creation and ask if the user wants to open a stream now

---

## Opening a Project

1. Read the project's `plan.md` to display:
   - Objective
   - Stream list with statuses and blocking dependencies
2. List streams and offer to:
   - **Open an existing stream**
   - **Create a new stream**
   - **View project-level tasks/hours**
   - **Start a project-level session**

---

## Creating a New Stream

1. Ask for the stream name (kebab-case for folder)
2. Ask for objective / scope
3. Ask which streams (if any) this stream is blocked by
4. Create the stream directory with `plan.md`, `session.md`, `hours.md`
5. Update the project's `plan.md` to add the new stream with `planned` status and its dependencies
6. Confirm creation and ask if the user wants to start a session

---

## Opening a Stream

1. Display the stream's `plan.md` (objective, tasks, acceptance criteria)
2. Show recent sessions from `session.md`
3. Show total hours from `hours.md`
4. Ask what the user wants to do:
   - **Start a session** (begin active work)
   - **Log time manually** (add past work)
   - **Update the plan**
   - **Mark stream complete**

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

When the user signals they're done (says "end session", "stop session", "done for now", "wrapping up"):

1. Record end time
2. Calculate duration — **round to nearest 15 minutes**
3. Ask what was accomplished (brief notes)
4. Append completed session to stream `session.md`
5. Append an entry to stream `hours.md`
6. Append an entry to project-level `tasks.md`
7. Update the project-level `session.md`

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
    ├── plan.md           # Master plan: objective, streams, dependencies, statuses
    ├── session.md        # Project-level session log (all streams combined)
    ├── tasks.md          # All tasks logged across streams with time
    └── streams/
        └── <stream-name>/
            ├── plan.md   # Stream scope, tasks checklist, acceptance criteria
            ├── session.md # Stream-level session log
            └── hours.md  # Time entries for this stream
```

See [references/file-formats.md](references/file-formats.md) for exact file formats.

---

## tmux Integration

Each project gets a dedicated tmux session (`pm-<project-name>`) with one window per open stream. Each stream window runs its own independent `claude` instance.

### Opening a Project in tmux

When the user asks to open a project in tmux or work on streams in parallel, run:

```bash
project-tmux open <project-name>
```

If the script is not installed yet, tell the user to install it first:

```bash
cp ~/.claude/plugins/installed/claude-skills/skills/project-manager/scripts/project-tmux.sh ~/bin/project-tmux
chmod +x ~/bin/project-tmux
```

See [references/tmux-setup.md](references/tmux-setup.md) for alias setup and status bar config.

### Opening a Single Stream in tmux

```bash
project-tmux stream <project-name> <stream-name>
```

This:
1. Creates the project tmux session if it doesn't exist
2. Writes a `CLAUDE.md` into the stream directory with project/stream context
3. Opens a new tmux window named after the stream
4. Starts `claude` in that window — it reads `CLAUDE.md` automatically on launch

### Running Parallel Streams

When the user wants to work on multiple streams simultaneously:

1. Identify which streams are currently unblocked (check `plan.md`)
2. Suggest the streams that can run in parallel based on the dependency map
3. Run:

```bash
project-tmux parallel <project-name> <stream1> <stream2> <stream3> ...
```

Each stream gets its own tmux window and Claude instance. The user switches between them with `Prefix + <window-number>`.

**Example — opening Wave 4 streams in parallel:**
```bash
project-tmux parallel braindump-notes \
  auto-append inline-editing paginated-scroll \
  background-sync color-rotation hand-drawn-rendering
```

### Checking Active Sessions

```bash
project-tmux list     # list all active project sessions
project-tmux attach <project-name>   # reconnect to a session
project-tmux kill <project-name>     # end a session
```

---

## Updating Stream Status

When a stream is marked complete, update the project `plan.md`:
- Change status to `complete`
- Check if any other streams were blocked by this one and update their status to `unblocked` if all blockers are resolved

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`
