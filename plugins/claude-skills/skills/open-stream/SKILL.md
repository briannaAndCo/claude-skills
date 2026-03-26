---
name: open-stream
description: This skill should be used when the user asks to "open a stream", "open stream X", "work on stream X", "start stream X", "open a thread", "launch stream", "switch to stream", or wants to open a specific project stream in its own terminal window with tmux context and worktree isolation. Opens a stream in a new terminal tab with a dedicated tmux session, git worktree (for code streams) or temporary docs directory (for non-code streams like research/planning), and a CLAUDE.md with full project and stream context.
version: 1.0.0
---

# Open Stream

Opens a project stream in a new terminal tab with a dedicated tmux session, isolated working directory, and full project context injected via CLAUDE.md.

**Code streams** (feature, bug, refactor, ops) get a git worktree on `stream/<name>` branch.
**Non-code streams** (research, planning, documentation, spike) get a persistent docs workspace at `~/.claude/stream-workspaces/<project>/<stream>/`.

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
1. If a project path or name was provided (e.g., from `open-project`), use it directly
2. If the user specified a project name, match against `projects[].name` in the registry
3. If inside a git repo, check if that repo is registered
4. If ambiguous, delegate to `open-project` to let the user pick

Extract `path` and `metaBranch` for the matched project. If no project is found, tell the user to create one first with the `create-project` skill.

### 2. Validate the Stream

The stream name must be provided — either by the user directly or passed from `open-project`. If no stream name was given, delegate to `open-project` to show the streams table and let the user pick.

Verify the stream exists on the meta branch:

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/plan.md 2>/dev/null
```

If the stream doesn't exist on meta, ask the user if they want to create it (delegate to `open-project`'s new-stream flow).

### 3. Check for Existing Session

Before creating anything, check if a tmux session already exists:

```bash
tmux has-session -t "<project>--<stream>" 2>/dev/null
```

If it exists, open a new terminal tab that attaches to it and stop:

```bash
# Detect terminal (iTerm2 or Terminal.app) and open a tab with:
tmux attach-session -t "<project>--<stream>"
```

Use AppleScript to open the tab (see [Opening a Terminal Tab](#opening-a-terminal-tab)).

Tell the user: "Stream `<stream>` is already running — attached to existing session."

**Return here. Do not proceed to later steps.**

### 4. Determine Stream Type

Read the stream's plan from the meta branch:

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/plan.md
```

Classify as **code** or **non-code**:

**Non-code indicators** (any match):
- Plan contains keywords: `research`, `investigate`, `spike`, `explore`, `documentation`, `planning`, `analysis`, `study`, `evaluation`, `comparison`, `decision`, `ADR`, `RFC`
- Stream name starts with: `research-`, `spike-`, `docs-`, `plan-`, `adr-`, `rfc-`, `explore-`
- Plan explicitly states `type: research`, `type: docs`, `type: planning`, or similar

**Everything else is a code stream.**

If uncertain, ask: "Does this stream involve code changes, or is it research/documentation only?"

### 5. Set Up Working Directory and CLAUDE.md

#### Code Streams — Git Worktree

Create or reuse a worktree at `<repo>/.worktrees/<stream>`:

```bash
# Ensure .worktrees is in .gitignore
grep -q '\.worktrees' <repo>/.gitignore 2>/dev/null || echo '.worktrees' >> <repo>/.gitignore

BRANCH="stream/<stream>"
WORKTREE="<repo>/.worktrees/<stream>"

if [ -d "$WORKTREE" ]; then
  echo "Worktree already exists"
elif git -C <repo> show-ref --quiet "refs/heads/$BRANCH"; then
  git -C <repo> worktree add "$WORKTREE" "$BRANCH"
else
  git -C <repo> worktree add -b "$BRANCH" "$WORKTREE" main
fi
```

Then use the **Write tool** to create `$WORKTREE/CLAUDE.md`:

```markdown
# Stream: <stream-name>

## Project: <project-name>
<project objective from plan.md>

## This Stream
<full content of streams/<stream>/plan.md from meta branch>

## Context
- Worktree: <worktree-path>
- Branch: stream/<stream-name>
- Base: main
- Repo: <repo-path>
- Meta branch: <meta-branch>

## Instructions
- Work only within this worktree
- Commit on branch stream/<stream-name>
- Do not modify files outside this stream's scope
- Follow codebase conventions
- Always commit on a feature branch, never on main
- When done, signal readiness for review

## On Start
1. Read this stream's plan above
2. Read relevant project context from the meta branch if needed:
   `git show <meta-branch>:design.md`, `git show <meta-branch>:requirements.md`, etc.
3. If the plan has an Approach and Tasks section, begin implementation
4. If the plan only has high-level AC, run the stream design pass first:
   explore the codebase, ask clarifying questions, propose approach,
   refine AC, break into tasks — then present for approval before coding
```

#### Non-Code Streams — Docs Workspace

Create a persistent docs workspace:

```bash
WORKSPACE="$HOME/.claude/stream-workspaces/<project-slug>/<stream>"
mkdir -p "$WORKSPACE"
```

Then use the **Write tool** to create `$WORKSPACE/CLAUDE.md`:

```markdown
# Stream: <stream-name>

## Project: <project-name>
<project objective from plan.md>

## This Stream
<full content of streams/<stream>/plan.md from meta branch>

## Context
- Workspace: <workspace-path>
- Repo (read-only reference): <repo-path>
- Meta branch: <meta-branch>
- Type: research/docs (no code changes expected)

## Instructions
- This is a non-code stream — no git worktree is attached
- Store all notes, docs, and artifacts in this workspace directory
- Reference the repo at <repo-path> for reading code, but do not modify it
- To read project planning files: `git -C <repo-path> show <meta-branch>:<file>`
- Summarize findings in a deliverable document when done

## On Start
1. Read this stream's plan above
2. Read relevant project context from the meta branch if needed
3. Begin research/investigation per the plan's objectives
4. Create documents in this workspace as you go
```

### 6. Open in Terminal with tmux

Build a tmux session with a styled status bar and launch it in a new terminal tab.

#### Determine visual identity

**Stream type color** (Interlace palette):

| Type     | tmux color   |
|----------|-------------|
| feature  | colour24    |
| bug      | colour124   |
| refactor | colour55    |
| research | colour130   |
| ops      | colour28    |

**Status indicator** (read from meta branch plan.md streams table):

| Status      | Indicator      |
|-------------|----------------|
| in-progress | `● active`     |
| unblocked   | `○ ready`      |
| blocked     | `✕ blocked`    |
| complete    | `✓ complete`   |
| planned     | `◌ planned`    |
| on-hold     | `⏸ on-hold`   |

**Description** from the Notes column in the plan.md streams table.

#### Build the tmux command

```bash
SESSION_NAME="<project>--<stream>"
WORK_DIR="<working-directory>"  # worktree path or docs workspace path

tmux new-session -s "$SESSION_NAME" -c "$WORK_DIR" \
  \; set status on \
  \; set status-position top \
  \; set status-style "bg=$COLOR,fg=white,bold" \
  \; set status-left "  $INDICATOR  │" \
  \; set status-left-length 20 \
  \; set status-right "│  $NOTES  " \
  \; set status-right-length 80 \
  \; set status-justify centre \
  \; set window-status-current-format " $STREAM_NAME " \
  \; set window-status-format " $STREAM_NAME " \
  \; send-keys "claude" Enter
```

#### Opening a Terminal Tab

Open the tmux command in a new terminal tab using AppleScript via the Bash tool.

Detect the terminal:

```bash
osascript -e 'tell application "System Events" to (name of processes) contains "iTerm2"' 2>/dev/null
```

**iTerm2:**
```bash
osascript -e '
tell application "iTerm2"
  tell current window
    create tab with default profile
    tell current session
      write text "<tmux-command>"
    end tell
  end tell
end tell'
```

**Terminal.app:**
```bash
osascript -e '
tell application "Terminal"
  tell application "System Events" to keystroke "t" using command down
  delay 0.3
  do script "<tmux-command>" in front window
end tell'
```

### 7. Update Stream Status on Meta Branch

If the stream's current status is `unblocked` or `planned`, update it to `in-progress`.

```bash
cd <repo-path>
git stash --include-untracked 2>/dev/null || true
CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
git checkout <meta-branch>
```

Use the **Edit tool** to update the stream's status in `plan.md`.

```bash
git add plan.md
git commit -m "meta: mark <stream> in-progress"
git checkout "$CURRENT_BRANCH" 2>/dev/null || git checkout main
git stash pop 2>/dev/null || true
```

### 8. Confirm

Tell the user:
- Stream opened in new terminal tab
- tmux session: `<project>--<stream>`
- Working directory: worktree path (code) or workspace path (non-code)
- Branch: `stream/<stream-name>` (code streams only)
- How to switch: look for the new terminal tab

---

## Cleaning Up

When a stream is marked complete, the user can optionally:

1. **Code streams**: Remove the worktree
   ```bash
   git -C <repo> worktree remove .worktrees/<stream>
   git -C <repo> branch -d stream/<stream>  # only if merged
   ```

2. **Non-code streams**: Archive the docs workspace
   ```bash
   mkdir -p ~/.claude/stream-workspaces/<project>/.archive
   mv ~/.claude/stream-workspaces/<project>/<stream> \
      ~/.claude/stream-workspaces/<project>/.archive/<stream>
   ```

Do not clean up automatically — always ask first.

---

## Important Notes

- **Use the Write tool for creating CLAUDE.md, Edit tool for modifying files, Read tool for reading.** Only use Bash for git commands, tmux commands, directory creation, and AppleScript.
- **Always create feature branches, never commit to main.** (Per user preference.)
- Stream type detection is conservative: when in doubt, treat as a code stream.
- The tmux session naming convention is `<project>--<stream>` (double dash separator).
- CLAUDE.md files on worktrees are ephemeral — regenerated on each open. Don't rely on them persisting.
- When this skill is called from `open-project`, the project and stream are already resolved — skip straight to step 3.
