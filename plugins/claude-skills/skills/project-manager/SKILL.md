---
name: project-manager
description: This skill should be used when the user asks to "open projects", "manage projects", "new project", "create project", "open a stream", "start a session", "log time", "track time", "project manager", "what projects do I have", "show my projects", "open tmux", "start parallel streams", "run streams in parallel", "set up tmux for project", "work on multiple streams", or mentions working on an epic, story, ticket, or stream. Manages structured project and stream workspaces with session tracking, time logging, and tmux-based parallel Claude instances.
version: 1.3.0
disable-model-invocation: true
---

# Project Manager

Manages a structured workspace of projects (epics) and streams (stories/tickets) with session logging and time tracking.

## Environment Assumption

**Claude is always running inside a tmux session.** The user launches Claude via the `ct` alias (`tmux new-session -A -s claude`). This means:

- When opening a stream, always open it in a **new tmux window** in the current session
- When the user wants parallel work, open multiple windows — one per stream
- The script to manage tmux is `~/bin/project-tmux`. Check if the `pt` alias exists first with `which pt 2>/dev/null`, and use `pt` if available, otherwise use `~/bin/project-tmux`

---

## Configuration

Read config with:

```bash
cat ~/.claude-projects-config 2>/dev/null || echo '{"projects_root": "~/projects"}'
```

Default `projects_root` is `~/projects`. If the user specifies a different location, write or update the config file.

---

## Entry Point: Opening the Projects Workspace

When the skill is invoked, immediately run these Bash tool calls in parallel:

```bash
cat ~/.claude-projects-config 2>/dev/null || echo '{"projects_root": "~/projects"}'
```

```bash
ls ~/projects 2>/dev/null
```

For each project found, read its objective:

```bash
grep -A1 "^## Objective" ~/projects/<project>/plan.md 2>/dev/null | tail -1
```

Show a numbered list:
```
1. braindump-notes — Mobile-first note-taking app
2. my-api — REST API backend
```

Ask: "Which project do you want to open? Or say **new** to create one."

If no projects exist, go straight to creating one.

---

## Creating a New Project

1. Ask for the project name (kebab-case)
2. Ask for a one-line objective
3. Ask for initial streams (optional)
4. Create the project structure (see [File Structure](#file-structure))
5. Populate `plan.md` with the objective, streams table, and dependency map
6. Confirm creation, then offer to open: `~/bin/project-tmux open <project>`

---

## Opening a Project

Read the project plan:

```bash
cat ~/projects/<project>/plan.md
```

Show the full streams status table — all streams, not just unblocked ones:

```
Streams:
| Stream                  | Status      | Blocked By                          |
|-------------------------|-------------|-------------------------------------|
| continuous-notebook     | unblocked   | —                                   |
| settings-and-themes     | unblocked   | —                                   |
| note-prioritization     | blocked     | continuous-notebook                 |
| copy-paste              | blocked     | continuous-notebook                 |
| reminders-and-alarms    | blocked     | continuous-notebook, settings-and-themes |
| quick-capture-widget    | blocked     | continuous-notebook                 |
| speech-to-text          | blocked     | continuous-notebook                 |
```

If the project has sub-streams, show those too (grouped under their parent stream).

Then ask: "Which stream do you want to open? Say **parallel** to open multiple, or **new** to create a stream."

---

## Creating a New Stream

1. Ask for the stream name (kebab-case)
2. Ask for objective / scope
3. Ask which streams (if any) this is blocked by
4. Create the stream directory with `plan.md`, `session.md`, `hours.md`
5. Update the project's `plan.md` streams table with `planned` status and dependencies
6. Offer to open it: `~/bin/project-tmux stream <project> <stream>`

---

## Opening a Stream

Run using the Bash tool:

```bash
~/bin/project-tmux stream <project> <stream>
```

This writes `CLAUDE.md` into the stream directory, opens a new tmux window named after the stream, and starts `claude` in it.

The Claude instance in that window is independent. The user switches to it with `Prefix + <window-number>`.

Once inside a stream window, that Claude instance should:
1. Read and display the stream's `plan.md` (objective, tasks, acceptance criteria)
2. Show recent sessions from `session.md` and total hours from `hours.md`
3. Ask what the user wants to do:
   - **Start a session**
   - **Log time manually**
   - **Update the plan**
   - **Mark stream complete**

---

## Running Parallel Streams

```bash
~/bin/project-tmux parallel <project> <stream1> <stream2> ...
```

Each stream gets its own tmux window and independent Claude instance.

When the user says "parallel", read `plan.md`, show all unblocked/in-progress streams, and ask which ones to open together.

---

## Session Management

### Starting a Session

Record start time in the stream's `session.md`:

```markdown
## Session: YYYY-MM-DD HH:MM
- **Status**: in-progress
```

Also update the project-level `session.md`.

### Ending a Session

When the user says "end session", "stop session", "done for now", "wrapping up", or "save session":

1. Record end time
2. Calculate duration — **round to nearest 15 minutes**
3. Ask what was accomplished (brief notes)
4. Append completed session to stream `session.md`
5. Append entry to stream `hours.md`
6. Append entry to project-level `tasks.md`
7. Update project-level `session.md`

---

## Time Tracking Rules

- All durations rounded to nearest **15-minute increment**
- Format: `Xh Ym` (e.g., `1h 30m`, `0h 45m`, `2h 00m`)
- Minimum logged: `0h 15m`

---

## File Structure

```
<projects-root>/
└── <project-name>/
    ├── plan.md            # Master plan: objective, streams table, dependency map
    ├── session.md         # Project-level session log (all streams combined)
    ├── tasks.md           # All tasks logged across streams with time
    └── streams/
        └── <stream-name>/
            ├── CLAUDE.md  # Auto-generated context for Claude on window open
            ├── plan.md    # Stream scope, tasks checklist, acceptance criteria
            ├── session.md # Stream-level session log
            └── hours.md   # Time entries for this stream
```

---

## Updating Stream Status

When a stream is marked complete, update the project `plan.md`:
- Change status to `complete`
- Check if any blocked streams now have all blockers resolved; if so, change them to `unblocked`

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`
