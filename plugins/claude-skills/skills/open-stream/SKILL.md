---
name: open-stream
description: This skill should be used when the user asks to "open a stream", "open stream X", "work on stream X", "start stream X", "open a thread", "launch stream", "switch to stream", or wants to open a specific project stream in its own terminal window with tmux context and worktree isolation. Opens a stream in a new terminal tab with a dedicated tmux session, git worktree (for code streams) or temporary docs directory (for non-code streams like research/planning), and a CLAUDE.md with full project and stream context.
version: 1.1.0
---

# Open Stream

Opens a project stream in a new terminal tab with a dedicated tmux session, isolated working directory, and full project context injected via CLAUDE.md.

**Code streams** (feature, bug, refactor, ops) get a git worktree on `stream/<name>` branch.
**Non-code streams** (research, planning, documentation, spike) get a persistent docs workspace at `~/.claude/stream-workspaces/<project>/<stream>/`.

## Helper Script

All multi-step bash operations use `~/.claude/scripts/open-stream.sh`. This avoids compound commands that require individual permission approvals. Every bash call in this skill either uses the helper script or a simple single command.

```
~/.claude/scripts/open-stream.sh <action> [args...]
```

**Actions:**
- `check-session <project> <stream>` — returns "exists" or "none"
- `detect-terminal` — returns "iterm2" or "terminal"
- `setup-worktree <repo-path> <stream>` — creates/reuses worktree, returns "created|attached|existing:<path>"
- `create-meta-tracking <repo-path> <meta-branch> <stream> <wave> <blocked-by> <caps> <notes>` — creates status.md on meta, updates plan.md status
- `update-meta <repo-path> <meta-branch> <stream> <new-status>` — updates stream status in plan.md on meta branch
- `launch <project> <stream> <workdir> <color> <indicator> <notes> <launch-cmd>` — writes launch script, opens terminal tab with tmux session
- `attach <project> <stream>` — opens terminal tab attached to existing tmux session
- `cleanup-worktree <repo-path> <stream>` — removes worktree
- `archive-workspace <project> <stream>` — archives non-code stream workspace

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

Also check for a status.md (tracking-only, no plan yet):

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/status.md 2>/dev/null
```

#### If the stream directory doesn't exist on meta but IS listed in plan.md's Streams table

The stream was defined during project planning but its individual files haven't been created yet. Create a minimal tracking file using the helper script:

1. Extract the stream's row from `plan.md`'s Streams table to get: Wave, Blocked By, Caps, Notes
2. Run the helper:

```bash
~/.claude/scripts/open-stream.sh create-meta-tracking <repo-path> <meta-branch> <stream> "<wave>" "<blocked-by>" "<caps>" "<notes>"
```

This creates `streams/<stream>/status.md` on the meta branch, updates plan.md status to `in-progress`, commits, and returns to the original branch.

3. Continue to Step 3.

#### If the stream doesn't exist in plan.md at all

Ask the user if they want to create it (delegate to `open-project`'s new-stream flow).

### 3. Check for Existing Session

```bash
~/.claude/scripts/open-stream.sh check-session <project> <stream>
```

If output is `"exists"`, attach to it and stop:

```bash
~/.claude/scripts/open-stream.sh attach <project> <stream>
```

Tell the user: "Stream `<stream>` is already running — attached to existing session."

**Return here. Do not proceed to later steps.**

### 4. Determine Stream Type

**Prefer `project.json`** for type lookup (no parsing needed):

```bash
git -C <repo-path> show <meta-branch>:project.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['streams'].get('<stream>',{}).get('type','feature'))"
```

**Fallback** if `project.json` is missing — read the stream's plan:

```bash
git -C <repo-path> show <meta-branch>:streams/<stream>/plan.md 2>/dev/null
```

Check the `> Type:` line first. If absent, classify by keywords:

**Non-code types** (`research`, `docs`):
- Plan contains keywords: `research`, `investigate`, `spike`, `explore`, `documentation`, `planning`, `analysis`, `study`, `evaluation`, `comparison`, `decision`, `ADR`, `RFC`
- Stream name starts with: `research-`, `spike-`, `docs-`, `plan-`, `adr-`, `rfc-`, `explore-`

**Code types** (`feature`, `bug`, `refactor`, `ops`): everything else.

If uncertain, ask: "Does this stream involve code changes, or is it research/documentation only?"

### 5. Set Up Working Directory and CLAUDE.md

#### Code Streams — Git Worktree

```bash
~/.claude/scripts/open-stream.sh setup-worktree <repo-path> <stream>
```

Output tells you the worktree path (e.g., `created:/path/to/.worktrees/<stream>`).

Then use the **Bash tool** to write `CLAUDE.md` into the worktree via heredoc:

```bash
cat > <worktree-path>/CLAUDE.md << 'EOF'
<CLAUDE.md content — see template below>
EOF
```

**CLAUDE.md template for code streams:**

```markdown
# Stream: <stream-name>

## Project: <project-name>
<project objective from plan.md>

## This Stream
<full content of streams/<stream>/plan.md from meta branch, OR a summary from the streams table if only status.md exists>

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

## Model Selection
Use the right model for each task type:
- **Mechanical tasks** (1-2 files, clear specs, boilerplate): use Haiku or fast mode
- **Integration tasks** (multi-file, pattern matching, standard features): use Sonnet
- **Architecture/design/review** (complex decisions, cross-cutting concerns): use Opus
Switch with /model or let the orchestrator choose.

## On Start
1. If launched with `/stream-plan`, the planning skill will handle context gathering and planning
2. If launched with just `claude`, read the stream plan above and begin implementation
3. Read relevant project context from the meta branch if needed:
   `git show <meta-branch>:design.md`, `git show <meta-branch>:requirements.md`, etc.
4. Reference capability files for full requirements:
   `git show <meta-branch>:requirements/<cap-file>.md`
```

#### Non-Code Streams — Docs Workspace

```bash
mkdir -p ~/.claude/stream-workspaces/<project-slug>/<stream>
```

Then use the **Bash tool** to write `CLAUDE.md` via heredoc:

```bash
cat > ~/.claude/stream-workspaces/<project-slug>/<stream>/CLAUDE.md << 'EOF'
<CLAUDE.md content — see template below>
EOF
```

**CLAUDE.md template for non-code streams:**

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

## Model Selection
- **Research/exploration**: use Sonnet for broad searches, Opus for synthesis and analysis
- **Document writing**: use Opus for drafting, Sonnet for formatting and structure

## On Start
1. Read this stream's plan above
2. Read relevant project context from the meta branch if needed
3. Begin research/investigation per the plan's objectives
4. Create documents in this workspace as you go
```

### 6. Open in Terminal with tmux

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

#### Choose the launch command

- **If the stream has a `plan.md` on meta** (with an Approach and Tasks section): use `claude`
- **If the stream has no `plan.md` or only a `status.md`** (newly opened): use `claude "/stream-plan"`

#### Launch via helper script

```bash
~/.claude/scripts/open-stream.sh launch <project> <stream> <workdir> <color> "<indicator>" "<notes>" "<launch-cmd>"
```

This writes a launch script to `/tmp`, detects the terminal, and opens a new tab with the tmux session.

**When opening multiple streams**, add a 1-second sleep between launches:

```bash
~/.claude/scripts/open-stream.sh launch ...  # stream 1
sleep 1
~/.claude/scripts/open-stream.sh launch ...  # stream 2
sleep 1
~/.claude/scripts/open-stream.sh launch ...  # stream 3
```

### 7. Update Stream Status on Meta Branch

If the stream's current status is `unblocked` or `planned`, update it to `in-progress`:

```bash
~/.claude/scripts/open-stream.sh update-meta <repo-path> <meta-branch> <stream> in-progress
```

**Skip this step** if `create-meta-tracking` was already called in Step 2 (it already sets the status to `in-progress`).

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
   ~/.claude/scripts/open-stream.sh cleanup-worktree <repo-path> <stream>
   git -C <repo> branch -d stream/<stream>  # only if merged
   ```

2. **Non-code streams**: Archive the docs workspace
   ```bash
   ~/.claude/scripts/open-stream.sh archive-workspace <project> <stream>
   ```

Do not clean up automatically — always ask first.

---

## Important Notes

- **Use the helper script** (`~/.claude/scripts/open-stream.sh`) for all multi-step bash operations. This ensures no permission prompts.
- **Use `cat > <path> << 'EOF'` (Bash tool)** for writing CLAUDE.md files into worktrees. These files are ephemeral and regenerated on each open.
- **Always create feature branches, never commit to main.** (Per user preference.)
- Stream type detection is conservative: when in doubt, treat as a code stream.
- The tmux session naming convention is `<project>--<stream>` (double dash separator).
- When this skill is called from `open-project`, the project and stream are already resolved — skip straight to step 3.
