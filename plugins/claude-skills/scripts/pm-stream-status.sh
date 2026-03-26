#!/usr/bin/env bash
# pm-stream-status — Show a single stream's details (plan, recent sessions, hours)
# Usage: pm-stream-status <project> <stream>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

if [ $# -lt 2 ]; then echo "Usage: pm-stream-status <project> <stream>"; exit 1; fi
STREAM="$2"

echo "=== Stream: $STREAM ==="
echo ""

# Stream plan
PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$STREAM/plan.md" 2>/dev/null || true)
if [ -n "$PLAN" ]; then
  echo "$PLAN"
else
  echo "(no plan found)"
fi

echo ""
echo "--- Recent Sessions ---"
SESSIONS=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$STREAM/session.md" 2>/dev/null || true)
if [ -n "$SESSIONS" ]; then
  echo "$SESSIONS" | tail -20
else
  echo "(none)"
fi

echo ""
echo "--- Hours ---"
HOURS=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$STREAM/hours.md" 2>/dev/null || true)
if [ -n "$HOURS" ]; then
  echo "$HOURS" | grep -E "^\*\*Total\*\*|^\|" | tail -10
else
  echo "0h 00m"
fi
