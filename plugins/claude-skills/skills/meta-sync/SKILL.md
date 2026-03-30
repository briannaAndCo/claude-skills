---
name: meta-sync
description: This skill should be used when Claude needs to update the meta branch — logging sessions, updating stream status, recording hours, editing plans, or syncing project state. Also triggers when the user says "log session", "end session", "update status", "mark complete", "sync meta", or when any other skill needs to persist changes to the meta branch. Provides a safe worktree-based approach that never touches the user's working tree.
version: 1.1.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(bash *), Bash(jq *)
---

# Meta Sync

Safely updates the project's meta branch without touching the user's working tree. Uses a **temporary git worktree** — no stash/checkout dance, no risk of losing uncommitted work.

All meta branch updates across all skills MUST go through this skill or the `pm-meta-edit.sh` script.

---

## The Core Script: `pm-meta-edit.sh`

All updates use the shared script at `${CLAUDE_SKILL_DIR}/../../scripts/pm-meta-edit.sh`. It:
1. Creates a temporary worktree from the meta branch
2. Runs the edit operation
3. Commits changes
4. Removes the worktree
5. The user's working tree is never touched

### Script Location

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
# or find via pm wrapper:
# pm meta-edit <project> <subcommand> [args...]
```

---

## Built-in Operations (Zero LLM Cost)

For routine tracking, use the script's built-in subcommands directly via Bash. These are deterministic and don't need Claude's judgment.

### Update Stream Status

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --set-status <stream> <status>
```

Valid statuses: `planned` | `unblocked` | `in-progress` | `blocked` | `complete` | `on-hold`

Automatically unblocks downstream streams when a blocker is marked complete. Updates both `plan.md` and `project.json`.

### Log Session Start

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --session-start <stream>
```

Appends a timestamped entry to `streams/<stream>/session.md` and the project-level `session.md`.

### Log Session End

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --session-end <stream> "<duration>" "<summary>"
```

Appends to `streams/<stream>/hours.md`, `streams/<stream>/session.md`, and project-level `tasks.md`. Duration format: `Xh Ym` (e.g., `1h 30m`).

### Append to a File

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --append <file-path> "<content>"
```

Appends content to any file on the meta branch. File path is relative to the meta branch root (e.g., `streams/auth/plan.md`).

### Overwrite a File

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --write <file-path> "<content>"
```

Replaces the entire content of a file on the meta branch.

### Regenerate project.json

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> --sync-json
```

Rebuilds `project.json` from `plan.md`. Use after manual plan.md edits.

---

## Custom Edits (Requires Claude's Judgment)

For edits that need Claude to read, decide, and write — use the external command mode. The command receives the worktree path as its first argument.

### Pattern: Edit a Stream Plan

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> "meta: update <stream> plan" bash -c '
  WORKDIR="$1"
  # Read, modify, write back — files are at $WORKDIR/streams/<stream>/plan.md
  # Use python3 for structured edits
' _
```

However, for complex edits it's often easier to:
1. Read the file: `git -C <repo> show <meta-branch>:streams/<stream>/plan.md`
2. Prepare the new content in Claude's context
3. Write it via `--write`: `bash "$SCRIPTS/pm-meta-edit.sh" <project> --write "streams/<stream>/plan.md" "<new content>"`

### Pattern: Check Off a Task

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> "meta: check task in <stream>" python3 -c "
import sys
workdir = sys.argv[1]
plan_path = f'{workdir}/streams/<stream>/plan.md'
with open(plan_path, 'r') as f:
    content = f.read()
content = content.replace('- [ ] <task text>', '- [x] <task text>', 1)
with open(plan_path, 'w') as f:
    f.write(content)
"
```

### Pattern: Add a New Stream

```bash
bash "$SCRIPTS/pm-meta-edit.sh" <project> "meta: add stream <stream>" bash -c '
  WORKDIR="$1"
  mkdir -p "$WORKDIR/streams/<stream>"
  # Write plan.md, session.md, hours.md
  # Update plan.md streams table
  # Update project.json
'
```

But prefer delegating to the `create-stream` skill for this — it handles the full flow.

---

## When to Use What

| Action | Method | Cost |
|--------|--------|------|
| Status change | `--set-status` | Zero (script) |
| Session start | `--session-start` | Zero (script) |
| Session end | `--session-end` | Zero (script) |
| Check off task | `--write` with edited content | Minimal (Claude reads + script writes) |
| Edit plan/AC | Read via `git show`, Write via `--write` | Minimal |
| Create stream | `create-stream` skill | Normal |
| Sync project.json | `--sync-json` | Zero (script) |
| Push to remote | `git push` after any of the above | Zero |

---

## Pushing to Remote

After meta branch updates, push if the project has a remote:

```bash
REMOTE=$(git -C <repo-path> remote get-url origin 2>/dev/null || true)
if [ -n "$REMOTE" ]; then
  git -C <repo-path> push origin <meta-branch> --quiet
  echo "Pushed to $META_BRANCH"
fi
```

Only push after significant updates (status changes, session ends, plan edits). Don't push after every micro-edit.

---

## Integration with Other Skills

All skills that modify meta branch state should use `pm-meta-edit.sh`:

| Skill | What it updates | How |
|-------|----------------|-----|
| `open-stream` | Status → in-progress | `--set-status` |
| `create-stream` | New stream files + plan.md table | Custom command or `--write` |
| `project-manager` | Session start/end, hours | `--session-start`, `--session-end` |
| `review-stream` | Status → complete (on pass) | `--set-status` |
| `open-project` | Nothing (read-only) | N/A |

---

## Important Notes

- **Never checkout the meta branch in the user's working tree.** Always use the temporary worktree via `pm-meta-edit.sh`.
- **The trap in pm-meta-edit.sh auto-cleans the worktree** even if the script fails. No orphaned worktrees.
- **Concurrent edits are safe** — each invocation creates its own worktree. Git handles the merge on commit.
- **project.json and plan.md must stay in sync.** After editing plan.md directly, run `--sync-json`. The built-in `--set-status` updates both automatically.
