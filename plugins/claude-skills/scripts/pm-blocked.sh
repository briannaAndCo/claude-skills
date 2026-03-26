#!/usr/bin/env bash
# pm-blocked — Show blocked streams and their blockers
# Usage: pm-blocked <project-name-or-path>
set -euo pipefail

if [ $# -lt 1 ]; then echo "Usage: pm-blocked <project>"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null) || { echo "No meta branch found"; exit 1; }

found=0
echo "$PLAN" | while IFS='|' read -r _ stream status blocked notes _; do
  stream=$(echo "$stream" | xargs 2>/dev/null || true)
  status=$(echo "$status" | xargs 2>/dev/null || true)
  blocked=$(echo "$blocked" | xargs 2>/dev/null || true)
  [ -z "$stream" ] && continue
  [[ "$stream" == "Stream" ]] && continue
  [[ "$stream" == "-"* ]] && continue
  if [[ "$status" == "blocked" ]]; then
    echo "✕ $stream — blocked by: $blocked"
    found=1
  fi
done

[ "$found" -eq 0 ] 2>/dev/null && echo "No blocked streams."
