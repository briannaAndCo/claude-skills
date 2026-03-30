#!/usr/bin/env bash
# pm-sync-main — Fetch origin and merge main into the current stream branch
# Usage: pm-sync-main [<project>] [<stream>]
#   If no args, auto-detects from cwd (must be inside a worktree)
#
# Output (one line per event):
#   fetched                    — git fetch origin completed
#   merged:<commit>            — merge commit created
#   already-up-to-date         — no new changes on main
#   conflict:<count>           — merge conflicts found, needs manual resolution
#   error:<message>            — something went wrong
#
# Exit codes: 0 = success, 1 = error, 2 = conflicts need resolution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

# --- Determine working directory ---
if [ -n "${2:-}" ]; then
  STREAM="$2"
  # Check if worktree exists for this stream
  WORKTREE_PATH=$(git -C "$REPO_DIR" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{path=$2} /^branch refs\/heads\/stream\/'"$STREAM"'$/{print path}')
  if [ -z "$WORKTREE_PATH" ]; then
    echo "error:no worktree found for stream/$STREAM" >&2
    exit 1
  fi
  WORK_DIR="$WORKTREE_PATH"
else
  # Auto-detect from cwd
  WORK_DIR="$(pwd)"
  STREAM=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's|^stream/||')
fi

BRANCH=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ ! "$BRANCH" =~ ^stream/ ]]; then
  echo "error:not on a stream branch (current: $BRANCH)" >&2
  exit 1
fi

# --- Check for uncommitted changes ---
if ! git -C "$WORK_DIR" diff --quiet 2>/dev/null || ! git -C "$WORK_DIR" diff --cached --quiet 2>/dev/null; then
  echo "error:uncommitted changes — commit or stash before syncing" >&2
  exit 1
fi

# --- Fetch ---
git -C "$REPO_DIR" fetch origin 2>/dev/null
echo "fetched"

# --- Determine main branch name ---
MAIN_BRANCH="main"
if ! git -C "$REPO_DIR" rev-parse --verify "origin/$MAIN_BRANCH" &>/dev/null; then
  MAIN_BRANCH="master"
  if ! git -C "$REPO_DIR" rev-parse --verify "origin/$MAIN_BRANCH" &>/dev/null; then
    echo "error:cannot find origin/main or origin/master" >&2
    exit 1
  fi
fi

# --- Check if already up to date ---
MERGE_BASE=$(git -C "$WORK_DIR" merge-base HEAD "origin/$MAIN_BRANCH" 2>/dev/null)
ORIGIN_HEAD=$(git -C "$REPO_DIR" rev-parse "origin/$MAIN_BRANCH" 2>/dev/null)
if [ "$MERGE_BASE" = "$ORIGIN_HEAD" ]; then
  echo "already-up-to-date"
  exit 0
fi

# --- Count incoming changes ---
INCOMING=$(git -C "$WORK_DIR" rev-list --count "$MERGE_BASE".."origin/$MAIN_BRANCH" 2>/dev/null)

# --- Merge ---
MERGE_OUTPUT=$(git -C "$WORK_DIR" merge "origin/$MAIN_BRANCH" --no-edit 2>&1) || {
  # Check for conflicts
  CONFLICT_COUNT=$(git -C "$WORK_DIR" diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CONFLICT_COUNT" -gt 0 ]; then
    echo "conflict:$CONFLICT_COUNT"
    git -C "$WORK_DIR" diff --name-only --diff-filter=U 2>/dev/null | while read -r f; do
      echo "  $f"
    done
    exit 2
  fi
  echo "error:merge failed — $MERGE_OUTPUT" >&2
  exit 1
}

MERGE_COMMIT=$(git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null)
echo "merged:${MERGE_COMMIT:0:8} ($INCOMING commits from origin/$MAIN_BRANCH)"
