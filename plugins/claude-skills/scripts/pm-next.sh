#!/usr/bin/env bash
# pm-next — Show streams ready to work on (in-progress and unblocked)
# Usage: pm-next <project-name-or-path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

echo "Ready to work on:"
echo ""

# Try project.json first
PROJECT_JSON=$(git -C "$REPO_DIR" show "$META_BRANCH:project.json" 2>/dev/null || true)

if [ -n "$PROJECT_JSON" ]; then
  echo "$PROJECT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for name, info in data.get('streams', {}).items():
    status = info.get('status', '')
    notes = info.get('description', '')
    if status == 'in-progress':
        print(f'  ● {name} — {notes}')
    elif status == 'unblocked':
        print(f'  ○ {name} — {notes}')
"
else
  PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null) || { echo "No meta branch found"; exit 1; }

  echo "$PLAN" | while IFS='|' read -r _ stream status blocked notes _; do
    stream=$(echo "$stream" | xargs 2>/dev/null || true)
    status=$(echo "$status" | xargs 2>/dev/null || true)
    notes=$(echo "$notes" | xargs 2>/dev/null || true)
    [ -z "$stream" ] && continue
    [[ "$stream" == "Stream" ]] && continue
    [[ "$stream" == "-"* ]] && continue
    if [[ "$status" == "in-progress" ]]; then
      echo "  ● $stream — $notes"
    elif [[ "$status" == "unblocked" ]]; then
      echo "  ○ $stream — $notes"
    fi
  done
fi
