# tmux Setup for Project Manager

## Session Naming Convention

Each project gets one tmux session: `pm-<project-name>`

```
pm-braindump-notes
  window: overview          ← project plan.md
  window: continuous-notebook  ← claude running in stream dir
  window: data-model           ← claude running in stream dir
  window: sqlite-schema        ← claude running in stream dir
```

Switching windows: `Prefix + <window-number>` or `Prefix + n` / `Prefix + p`

---

## Installing the Helper Script

Copy (or symlink) `project-tmux.sh` to somewhere on your PATH:

```bash
cp ~/.claude/plugins/installed/claude-skills/skills/project-manager/scripts/project-tmux.sh ~/bin/project-tmux
chmod +x ~/bin/project-tmux
```

Or add an alias in `~/.zshrc`:

```bash
alias pt="~/.claude/plugins/installed/claude-skills/skills/project-manager/scripts/project-tmux.sh"
```

---

## Common Commands

```bash
# Open a project (shows plan.md in overview window)
project-tmux open braindump-notes

# Open a single stream with Claude
project-tmux stream braindump-notes continuous-notebook

# Open multiple streams in parallel (each gets its own window + Claude instance)
project-tmux parallel braindump-notes data-model sqlite-schema notebook-ui-scaffold

# Attach to an existing project session
project-tmux attach braindump-notes

# List all active project sessions
project-tmux list

# Kill a project session when done
project-tmux kill braindump-notes
```

---

## Recommended tmux Status Bar

Add to `~/.tmux.conf` to show the active project and stream in the status bar:

```tmux
# Show session (project) and window (stream) in status bar
set -g status-left-length 40
set -g status-left "#[fg=green,bold][#S] #[fg=white]"
set -g status-right "#[fg=cyan]#W #[fg=white]| %H:%M"
set -g status-style "bg=colour235 fg=white"
set -g window-status-current-style "fg=yellow,bold"

# Reload config
bind r source-file ~/.tmux.conf \; display "Config reloaded"
```

This gives a status bar like:
```
[pm-braindump-notes]  overview  data-model  sqlite-schema  │  continuous-notebook  14:32
```

---

## Parallel Workflow Example

Working on Wave 4 streams in parallel:

```bash
project-tmux parallel braindump-notes \
  auto-append \
  inline-editing \
  paginated-scroll \
  background-sync \
  color-rotation \
  hand-drawn-rendering
```

This opens 6 tmux windows, each with its own `claude` instance pre-loaded with the stream's `CLAUDE.md` context. Switch between them with `Prefix + <number>`.

---

## How Stream Context Works

When `project-tmux stream` or `project-tmux parallel` opens a window, it writes a `CLAUDE.md` into the stream directory before starting Claude:

```markdown
# Stream: data-model
**Project**: braindump-notes

You are working on the `data-model` stream of the `braindump-notes` project.
Read `plan.md` to understand your objectives, tasks, and acceptance criteria.
```

Claude reads this automatically on startup, giving each instance immediate project context without any manual setup.

---

## Tips

- Use `Prefix + &` to close a stream window when done
- Use `Prefix + $` to rename the session if you want a friendlier name
- Use `tmux kill-server` to nuke all sessions at end of day
- Sessions persist across terminal closes — `project-tmux attach <project>` to reconnect
