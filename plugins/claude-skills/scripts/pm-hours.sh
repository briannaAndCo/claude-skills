#!/usr/bin/env bash
# pm-hours — Show hours summary across all streams
# Usage: pm-hours <project-name-or-path>
set -euo pipefail

if [ $# -lt 1 ]; then echo "Usage: pm-hours <project>"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

# Try project-level tasks.md first
TASKS=$(git -C "$REPO_DIR" show "$META_BRANCH:tasks.md" 2>/dev/null || true)
if [ -n "$TASKS" ]; then
  echo "$TASKS"
  exit 0
fi

# Fall back to aggregating stream hours
echo "# Hours Summary"
echo ""
printf "%-25s %s\n" "Stream" "Total"
printf "%-25s %s\n" "-------------------------" "----------"

STREAMS=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null | grep "^|" | tail -n +3 | awk -F'|' '{gsub(/^ +| +$/, "", $2); if ($2 != "" && $2 !~ /^-/) print $2}')

total_min=0
while read -r stream; do
  [ -z "$stream" ] && continue
  hours_content=$(git -C "$REPO_DIR" show "$META_BRANCH:streams/$stream/hours.md" 2>/dev/null || true)
  if [ -n "$hours_content" ]; then
    total_line=$(echo "$hours_content" | grep "^\*\*Total\*\*" | tail -1)
    if [ -n "$total_line" ]; then
      printf "%-25s %s\n" "$stream" "$(echo "$total_line" | sed 's/\*\*Total\*\*: //')"
    else
      printf "%-25s %s\n" "$stream" "0h 00m"
    fi
  else
    printf "%-25s %s\n" "$stream" "0h 00m"
  fi
done <<< "$STREAMS"
