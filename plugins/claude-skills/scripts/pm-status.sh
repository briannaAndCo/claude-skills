#!/usr/bin/env bash
# pm-status — Show project overview: objective + streams table with status indicators
# Usage: pm-status <project-name-or-path>
set -euo pipefail

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

# Try project.json first
PROJECT_JSON=$(git -C "$REPO_DIR" show "$META_BRANCH:project.json" 2>/dev/null || true)

if [ -n "$PROJECT_JSON" ]; then
  # Use project.json for stream data
  printf "%-4s %-25s %-12s %-15s %-30s %s\n" "#" "Stream" "Type" "Status" "Notes" "Blocked By"
  printf "%-4s %-25s %-12s %-15s %-30s %s\n" "---" "-------------------------" "------------" "---------------" "------------------------------" "----------"

  echo "$PROJECT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
streams = data.get('streams', {})
for i, (name, info) in enumerate(streams.items(), 1):
    status = info.get('status', 'planned')
    stype = info.get('type', 'feature')
    blocked = ', '.join(info.get('blockedBy', [])) or '—'
    notes = info.get('description', '')[:30]
    # Status icon
    icons = {
        'in-progress': '● active', 'unblocked': '○ ready', 'blocked': '✕ blocked',
        'complete': '✓ complete', 'planned': '◌ planned', 'on-hold': '⏸ on-hold'
    }
    icon = icons.get(status, f'? {status}')
    print(f'{i:<4} {name:<25} {stype:<12} {icon:<15} {notes:<30} {blocked}')
"
else
  # Fall back to plan.md markdown parsing
  # Detect table format: 4-col or 5-col
  HEADER=$(echo "$PLAN" | grep -E '^\| *Stream *\|' | head -1)
  if echo "$HEADER" | grep -q 'Type'; then
    # 5-col format: Stream | Status | Type | Blocked By | Notes
    printf "%-4s %-25s %-12s %-15s %-30s %s\n" "#" "Stream" "Type" "Status" "Notes" "Blocked By"
    printf "%-4s %-25s %-12s %-15s %-30s %s\n" "---" "-------------------------" "------------" "---------------" "------------------------------" "----------"

    i=0
    echo "$PLAN" | while IFS='|' read -r _ stream status stype blocked notes _; do
      stream=$(echo "$stream" | xargs 2>/dev/null || true)
      status=$(echo "$status" | xargs 2>/dev/null || true)
      stype=$(echo "$stype" | xargs 2>/dev/null || true)
      blocked=$(echo "$blocked" | xargs 2>/dev/null || true)
      notes=$(echo "$notes" | xargs 2>/dev/null || true)
      [ -z "$stream" ] && continue
      [[ "$stream" == "Stream" ]] && continue
      [[ "$stream" == "-"* ]] && continue
      i=$((i + 1))
      icon=$(status_icon "$status")
      printf "%-4s %-25s %-12s %-15s %-30s %s\n" "$i" "$stream" "${stype:-feature}" "$icon" "${notes:0:30}" "${blocked:-—}"
    done
  else
    # 4-col format: Stream | Status | Blocked By | Notes
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
  fi
fi
