---
name: open-stream
description: This skill should be used when the user asks to "open a stream", "open stream X", "work on stream X", "start stream X", "open a thread", "launch stream", "switch to stream", or wants to open a specific project stream in its own terminal window with tmux context and worktree isolation. Opens a stream in a new terminal tab with a dedicated tmux session, git worktree (for code streams) or temporary docs directory (for non-code streams like research/planning), and a CLAUDE.md with full project and stream context.
version: 2.1.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(bash *), Bash(jq *), Bash(tmux *), Bash(osascript *), Bash(sleep *)
---

# Open Stream

Opens a project stream in a new terminal tab with a dedicated tmux session, isolated working directory, and full project context injected via CLAUDE.md.

**Code streams** (feature, bug, refactor, ops) get a git worktree on `stream/<name>` branch.
**Non-code streams** (research, planning, documentation, spike) get a persistent docs workspace at `~/.claude/stream-workspaces/<project>/<stream>/`.

---

## Primary Script

The entire open-stream flow is handled by a single script call:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
bash "$SCRIPTS/pm-open-stream.sh" <project> <stream>
```

This script handles everything in one invocation:
1. Resolves the project via `pm-resolve.sh`
2. Validates the stream exists on the meta branch
3. Checks for an existing tmux session (attaches if found)
4. Determines stream type from `project.json`
5. Sets up a git worktree (code) or workspace directory (non-code)
6. Generates CLAUDE.md with full project and stream context
7. Launches a tmux session in a new terminal tab with visual identity
8. Updates stream status to `in-progress` on the meta branch

**Output** (one line per event):
- `attached:<session>` — existing tmux session found, reattached
- `setup:<worktree-path>` — worktree created/reused
- `workspace:<workspace-path>` — non-code workspace created
- `launched:<session>` — tmux session launched in new tab
- `status:updated` — meta branch status set to in-progress
- `error:<message>` — something went wrong

**Optional flag:**
- `--claude-md <path>` — use a pre-written CLAUDE.md instead of auto-generating one

---

## Flow

### 1. Open a Single Stream

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
bash "$SCRIPTS/pm-open-stream.sh" <project> <stream>
```

Parse the output to confirm what happened and report to the user.

### 2. Open Multiple Streams

When opening multiple streams, call the script for each with a 1-second sleep between:

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
bash "$SCRIPTS/pm-open-stream.sh" <project> <stream1>
sleep 1
bash "$SCRIPTS/pm-open-stream.sh" <project> <stream2>
sleep 1
bash "$SCRIPTS/pm-open-stream.sh" <project> <stream3>
```

### 3. Confirm

Tell the user:
- Stream opened in new terminal tab
- tmux session: `<project>--<stream>`
- Working directory: worktree path (code) or workspace path (non-code)
- Branch: `stream/<stream-name>` (code streams only)
- How to switch: look for the new terminal tab

---

## Edge Cases

- **Stream not found** (exit code 2): Ask the user if they want to create it (delegate to `create-stream` skill)
- **Stream blocked**: The script opens it anyway — it's the user's choice. Warn them that it's marked blocked.
- **Stream already running**: Script auto-detects and reattaches. Output: `attached:<session>`

---

## Cleaning Up

When a stream is marked complete, the user can optionally:

1. **Code streams**: Remove the worktree
   ```bash
   ~/.claude/scripts/open-stream.sh cleanup-worktree <repo-path> <stream>
   git -C <repo> branch -d stream/<stream>  # only if merged
   ```

2. **Non-code streams**: Archive the docs workspace
   ```bash
   ~/.claude/scripts/open-stream.sh archive-workspace <project> <stream>
   ```

Do not clean up automatically — always ask first.

---

## Visual Identity Reference

**Stream type colors** (Interlace palette):

| Type     | tmux color   |
|----------|-------------|
| feature  | colour24    |
| bug      | colour124   |
| refactor | colour55    |
| research | colour130   |
| ops      | colour28    |

**Status indicators**:

| Status      | Indicator      |
|-------------|----------------|
| in-progress | `● active`     |
| unblocked   | `○ ready`      |
| blocked     | `✕ blocked`    |
| complete    | `✓ complete`   |
| planned     | `◌ planned`    |
| on-hold     | `⏸ on-hold`   |

---

## Important Notes

- **One script call does everything.** `pm-open-stream.sh` replaces all the individual step-by-step bash calls. No permission prompts needed beyond the single script invocation.
- The tmux session naming convention is `<project>--<stream>` (double dash separator).
- When this skill is called from `open-project`, the project and stream are already known — just pass them to the script.
- **Always create feature branches, never commit to main.** (Per user preference.)
- Stream type detection is conservative: when in doubt, treat as a code stream.
