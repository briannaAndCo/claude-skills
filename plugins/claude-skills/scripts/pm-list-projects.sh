#!/usr/bin/env bash
# pm-list-projects — List all registered projects with objectives
# Usage: pm-list-projects
set -euo pipefail

REGISTRY="$HOME/.claude/projects-registry.json"

if [ ! -f "$REGISTRY" ]; then
  echo "No projects registered. Use create-project to set one up."
  exit 0
fi

PROJECTS=$(python3 -c "
import json, os
with open('$REGISTRY') as f:
    reg = json.load(f)
for i, p in enumerate(reg.get('projects', []), 1):
    print(f\"{i}|{p['name']}|{os.path.expanduser(p['path'])}|{p.get('metaBranch', 'meta/' + p['name'])}\")
" 2>/dev/null || true)

if [ -z "$PROJECTS" ]; then
  echo "No projects registered."
  exit 0
fi

printf "%-4s %-25s %s\n" "#" "Project" "Objective"
printf "%-4s %-25s %s\n" "---" "-------------------------" "----------------------------------------"

echo "$PROJECTS" | while IFS='|' read -r num name path meta; do
  objective=$(git -C "$path" show "$meta:plan.md" 2>/dev/null | sed -n '/^## Objective$/,/^##/{/^##/!p;}' | head -1 | xargs 2>/dev/null || echo "(no objective)")
  printf "%-4s %-25s %s\n" "$num" "$name" "${objective:0:50}"
done
