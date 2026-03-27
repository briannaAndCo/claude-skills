#!/usr/bin/env bash
# pm-open-stream — Open a project stream in one shot
# Resolves project, validates stream, sets up worktree/workspace, generates
# CLAUDE.md, launches tmux session in a new terminal tab, and updates meta status.
#
# Usage: pm-open-stream <project> <stream> [--claude-md <path>]
#   --claude-md <path>  Path to a pre-written CLAUDE.md to use instead of auto-generating
#
# Output (one line per event):
#   attached:<session>           — existing tmux session found, attached
#   setup:<worktree-path>        — worktree created/reused
#   workspace:<workspace-path>   — non-code workspace created
#   launched:<session>           — tmux session launched in new tab
#   status:updated               — meta branch status set to in-progress
#   error:<message>              — something went wrong
#
# Exit codes: 0 = success, 1 = error, 2 = stream not found

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$HOME/.claude/scripts/open-stream.sh"

# --- Parse args ---
PROJECT="${1:?Usage: pm-open-stream <project> <stream>}"
STREAM="${2:?Usage: pm-open-stream <project> <stream>}"
shift 2

CLAUDE_MD_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude-md) CLAUDE_MD_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# --- 1. Resolve project ---
source "$SCRIPT_DIR/pm-resolve.sh" "$PROJECT"
# Sets: REPO_DIR, META_BRANCH

if [ -z "${REPO_DIR:-}" ] || [ -z "${META_BRANCH:-}" ]; then
  echo "error:Could not resolve project '$PROJECT'"
  exit 1
fi

# --- 2. Validate stream exists ---
STREAM_PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$STREAM/plan.md" 2>/dev/null || true)
STREAM_STATUS=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$STREAM/status.md" 2>/dev/null || true)
PLAN_MD=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null || true)

# Check if stream is in plan.md streams table
IN_PLAN=false
if echo "$PLAN_MD" | grep -q "| $STREAM |"; then
  IN_PLAN=true
fi

if [ -z "$STREAM_PLAN" ] && [ -z "$STREAM_STATUS" ] && [ "$IN_PLAN" = false ]; then
  echo "error:Stream '$STREAM' not found on meta branch '$META_BRANCH'"
  exit 2
fi

# If stream is in plan but has no files on meta, create tracking
if [ -z "$STREAM_PLAN" ] && [ -z "$STREAM_STATUS" ] && [ "$IN_PLAN" = true ]; then
  # Extract info from plan.md table row
  ROW=$(echo "$PLAN_MD" | grep "| $STREAM |" | head -1)
  bash "$HELPER" create-meta-tracking "$REPO_DIR" "$META_BRANCH" "$STREAM" "" "" "" "" >/dev/null 2>&1 || true
  STREAM_STATUS="auto-created"
fi

# --- 3. Check for existing tmux session ---
SESSION="${PROJECT}--${STREAM}"
if tmux has-session -t "$SESSION" 2>/dev/null; then
  bash "$HELPER" attach "$PROJECT" "$STREAM" >/dev/null 2>&1
  echo "attached:$SESSION"
  exit 0
fi

# --- 4. Determine stream type ---
PROJECT_JSON=$(git -C "$REPO_DIR" show "$META_BRANCH:project.json" 2>/dev/null || true)
STREAM_TYPE="feature"

if [ -n "$PROJECT_JSON" ]; then
  STREAM_TYPE=$(echo "$PROJECT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('streams', {}).get('$STREAM', {}).get('type', 'feature'))
" 2>/dev/null || echo "feature")
else
  # Fallback: check stream name prefix
  case "$STREAM" in
    research-*|spike-*|docs-*|plan-*|adr-*|rfc-*|explore-*) STREAM_TYPE="research" ;;
  esac
fi

IS_CODE=true
case "$STREAM_TYPE" in
  research|docs|documentation|planning|spike) IS_CODE=false ;;
esac

# --- 5. Set up working directory ---
WORKDIR=""

if [ "$IS_CODE" = true ]; then
  RESULT=$(bash "$HELPER" setup-worktree "$REPO_DIR" "$STREAM")
  WORKDIR=$(echo "$RESULT" | sed 's/^[a-z]*://')
  echo "setup:$WORKDIR"
else
  WORKDIR="$HOME/.claude/stream-workspaces/$PROJECT/$STREAM"
  mkdir -p "$WORKDIR"
  echo "workspace:$WORKDIR"
fi

# --- 6. Write CLAUDE.md ---
PROJECT_NAME=$(echo "$PLAN_MD" | head -1 | sed 's/^# *//')
OBJECTIVE=$(echo "$PLAN_MD" | sed -n '/^## Objective$/,/^##/{/^##/!p;}' | head -5)

if [ -n "$CLAUDE_MD_PATH" ] && [ -f "$CLAUDE_MD_PATH" ]; then
  cp "$CLAUDE_MD_PATH" "$WORKDIR/CLAUDE.md"
elif [ "$IS_CODE" = true ]; then
  STREAM_CONTENT="${STREAM_PLAN:-No plan.md found — run /stream-plan to create one.}"
  cat > "$WORKDIR/CLAUDE.md" << CLAUDEMD_EOF
# Stream: $STREAM

## Project: $PROJECT_NAME
$OBJECTIVE

## This Stream
$STREAM_CONTENT

## Context
- Worktree: $WORKDIR
- Branch: stream/$STREAM
- Base: main
- Repo: $REPO_DIR
- Meta branch: $META_BRANCH

## Instructions
- Work only within this worktree
- Commit on branch stream/$STREAM
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
1. If launched with \`/stream-plan\`, the planning skill will handle context gathering and planning
2. If launched with just \`claude\`, read the stream plan above and begin implementation
3. Read relevant project context from the meta branch if needed:
   \`git show $META_BRANCH:design.md\`, \`git show $META_BRANCH:requirements.md\`, etc.
4. Reference capability files for full requirements:
   \`git show $META_BRANCH:requirements/<cap-file>.md\`
CLAUDEMD_EOF
else
  STREAM_CONTENT="${STREAM_PLAN:-No plan.md found — run /stream-plan to create one.}"
  cat > "$WORKDIR/CLAUDE.md" << CLAUDEMD_EOF
# Stream: $STREAM

## Project: $PROJECT_NAME
$OBJECTIVE

## This Stream
$STREAM_CONTENT

## Context
- Workspace: $WORKDIR
- Repo (read-only reference): $REPO_DIR
- Meta branch: $META_BRANCH
- Type: $STREAM_TYPE (no code changes expected)

## Instructions
- This is a non-code stream — no git worktree is attached
- Store all notes, docs, and artifacts in this workspace directory
- Reference the repo at $REPO_DIR for reading code, but do not modify it
- To read project planning files: \`git -C $REPO_DIR show $META_BRANCH:<file>\`
- Summarize findings in a deliverable document when done

## Model Selection
- **Research/exploration**: use Sonnet for broad searches, Opus for synthesis and analysis
- **Document writing**: use Opus for drafting, Sonnet for formatting and structure

## On Start
1. Read this stream's plan above
2. Read relevant project context from the meta branch if needed
3. Begin research/investigation per the plan's objectives
4. Create documents in this workspace as you go
CLAUDEMD_EOF
fi

# --- 7. Determine visual identity and launch ---
case "$STREAM_TYPE" in
  feature)  COLOR="colour24" ;;
  bug)      COLOR="colour124" ;;
  refactor) COLOR="colour55" ;;
  research) COLOR="colour130" ;;
  ops)      COLOR="colour28" ;;
  *)        COLOR="colour24" ;;
esac

# Get current status for indicator
CURRENT_STATUS=$(echo "$PROJECT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('streams', {}).get('$STREAM', {}).get('status', 'planned'))
" 2>/dev/null || echo "planned")

case "$CURRENT_STATUS" in
  in-progress) INDICATOR="● active" ;;
  unblocked)   INDICATOR="○ ready" ;;
  blocked)     INDICATOR="✕ blocked" ;;
  complete)    INDICATOR="✓ complete" ;;
  planned)     INDICATOR="◌ planned" ;;
  on-hold)     INDICATOR="⏸ on-hold" ;;
  *)           INDICATOR="? $CURRENT_STATUS" ;;
esac

# Get description from project.json
NOTES=$(echo "$PROJECT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('streams', {}).get('$STREAM', {}).get('description', '')[:40])
" 2>/dev/null || echo "")

# Choose launch command
LAUNCH_CMD="claude"
if [ -z "$STREAM_PLAN" ]; then
  LAUNCH_CMD='claude "/stream-plan"'
fi

bash "$HELPER" launch "$PROJECT" "$STREAM" "$WORKDIR" "$COLOR" "$INDICATOR" "$NOTES" "$LAUNCH_CMD" >/dev/null 2>&1
echo "launched:$SESSION"

# --- 8. Update status on meta if needed ---
if [ "$CURRENT_STATUS" = "unblocked" ] || [ "$CURRENT_STATUS" = "planned" ]; then
  bash "$SCRIPT_DIR/pm-meta-edit.sh" "$REPO_DIR" --set-status "$STREAM" in-progress >/dev/null 2>&1 || true
  echo "status:updated"
fi
