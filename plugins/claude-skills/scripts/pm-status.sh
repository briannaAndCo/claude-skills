#!/usr/bin/env bash
# pm-status — Show project overview: objective + streams table with status indicators
# Usage: pm-status <project-name-or-path>
set -euo pipefail

if [ $# -lt 1 ]; then echo "Usage: pm-status <project>"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null) || { echo "No meta branch found at $REPO_DIR"; exit 1; }

# Project name and objective
echo "$PLAN" | head -1
echo ""
echo "$PLAN" | sed -n '/^## Objective$/,/^##/{/^##/!p;}' | head -5
echo ""

# Status indicator mapping
status_icon() {
  case "$1" in
    in-progress) echo "● active" ;;
    unblocked)   echo "○ ready" ;;
    blocked)     echo "✕ blocked" ;;
    complete)    echo "✓ complete" ;;
    planned)     echo "◌ planned" ;;
    on-hold)     echo "⏸ on-hold" ;;
    *)           echo "? $1" ;;
  esac
}

# Parse and display streams table
printf "%-4s %-25s %-15s %-30s %s\n" "#" "Stream" "Status" "Notes" "Blocked By"
printf "%-4s %-25s %-15s %-30s %s\n" "---" "-------------------------" "---------------" "------------------------------" "----------"

i=0
echo "$PLAN" | while IFS='|' read -r _ stream status blocked notes _; do
  stream=$(echo "$stream" | xargs 2>/dev/null || true)
  status=$(echo "$status" | xargs 2>/dev/null || true)
  blocked=$(echo "$blocked" | xargs 2>/dev/null || true)
  notes=$(echo "$notes" | xargs 2>/dev/null || true)
  [ -z "$stream" ] && continue
  [[ "$stream" == "Stream" ]] && continue
  [[ "$stream" == "-"* ]] && continue
  i=$((i + 1))
  icon=$(status_icon "$status")
  printf "%-4s %-25s %-15s %-30s %s\n" "$i" "$stream" "$icon" "${notes:0:30}" "${blocked:-—}"
done
