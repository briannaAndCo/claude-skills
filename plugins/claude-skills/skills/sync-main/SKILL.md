---
name: sync-main
description: This skill should be used when the user asks to "sync main", "merge main", "pull main", "update from main", "rebase from main", "get latest", "sync stream", or wants to incorporate the latest origin/main changes into their current stream branch. Fetches origin and merges main into the stream branch, handling conflicts if they arise.
version: 1.0.0
allowed-tools: Read, Glob, Grep, Edit, Bash(git *), Bash(bash *), Bash(SCRIPTS=*)
---

# Sync Main

Fetches `origin` and merges `origin/main` into the current stream branch. Handles conflict detection and guides resolution.

---

## Primary Script

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
bash "$SCRIPTS/pm-sync-main.sh" [<project>] [<stream>]
```

If no arguments, auto-detects from the current working directory.

**Output:**
- `fetched` — git fetch completed
- `merged:<commit> (<N> commits from origin/main)` — merge succeeded
- `already-up-to-date` — nothing new on main
- `conflict:<count>` — merge conflicts, followed by conflicted file paths
- `error:<message>` — something went wrong

**Exit codes:** 0 = success, 1 = error, 2 = conflicts need resolution

---

## Flow

### 1. Run the Script

```bash
SCRIPTS="${CLAUDE_SKILL_DIR}/../../scripts"
bash "$SCRIPTS/pm-sync-main.sh" <project> <stream>
```

### 2. Handle the Result

#### Success (`merged:...`)
Report to the user:
```
Synced with origin/main — merged <N> commits into stream/<stream>.
```

#### Already up to date
```
Stream is already up to date with origin/main.
```

#### Conflicts (`conflict:<count>`)
List the conflicted files and offer to help resolve:

1. Read each conflicted file to understand the conflict
2. For each conflict, show the user both sides and propose a resolution
3. After resolving all files, stage them: `git add <file>`
4. Complete the merge: `git commit --no-edit`
5. Confirm resolution

#### Error
Report the error message and suggest remediation (e.g., "commit or stash your changes first").

### 3. Continue Work

After a successful sync, remind the user they can continue working. If inside a tmux stream session, the worktree is already pointing at the updated branch.

---

## When to Use

- **Before starting work** on a stream that's been idle — sync to avoid stale conflicts
- **Before creating a PR** — ensure the branch is up to date
- **When another stream merged to main** — pull in its changes if this stream depends on it
- **When the user says** "sync", "update", "pull main", "merge main", "get latest"

---

## Important Notes

- **Always merges, never rebases.** Merge preserves stream history and is safer for shared branches.
- **Requires a clean working tree.** The script will error if there are uncommitted changes — tell the user to commit or stash first.
- **Works from worktrees.** The script detects the repo root correctly even when run from a git worktree.
- **Auto-detects main vs master.** Falls back to `master` if `main` doesn't exist.
- **Files to never stage.** When operating in a work repo, never `git add` these paths — they are local-only and must not be committed or gitignored:
  - `CLAUDE.md`, `claude_docs/`, `.worktrees/`, `doc/architecture.md`
  - Git hook files (`.git/hooks/` — already untracked, but never copy them into the tree)
  - If you must use `git add -A` or `git add .`, exclude them: `git add -A -- ':!CLAUDE.md' ':!claude_docs' ':!.worktrees' ':!doc/architecture.md'`
