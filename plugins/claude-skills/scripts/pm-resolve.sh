#!/usr/bin/env bash
# pm-resolve — Resolve a project name to repo path and meta branch
# Usage: source pm-resolve.sh <project-name-or-path>
# Sets: REPO_DIR, META_BRANCH

REGISTRY="$HOME/.claude/projects-registry.json"

_pm_resolve() {
  local input="$1"

  # Direct path
  if [ -d "$input/.git" ]; then
    REPO_DIR="$input"
    # Try to find meta branch from registry
    if [ -f "$REGISTRY" ]; then
      META_BRANCH=$(python3 -c "
import json, os, sys
with open('$REGISTRY') as f:
    reg = json.load(f)
for p in reg.get('projects', []):
    if os.path.expanduser(p['path']) == os.path.realpath(sys.argv[1]):
        print(p.get('metaBranch', ''))
        break
" "$input" 2>/dev/null || true)
    fi
    [ -z "$META_BRANCH" ] && META_BRANCH=$(git -C "$REPO_DIR" branch --list 'meta/*' 2>/dev/null | head -1 | xargs)
    return 0
  fi

  # Name lookup in registry
  if [ -f "$REGISTRY" ]; then
    local result
    result=$(python3 -c "
import json, os, sys
with open('$REGISTRY') as f:
    reg = json.load(f)
for p in reg.get('projects', []):
    if p['name'] == sys.argv[1]:
        print(os.path.expanduser(p['path']) + '|' + p.get('metaBranch', 'meta/' + sys.argv[1]))
        break
" "$input" 2>/dev/null || true)
    if [ -n "$result" ]; then
      IFS='|' read -r REPO_DIR META_BRANCH <<< "$result"
      return 0
    fi
  fi

  echo "Project not found: $input" >&2
  return 1
}

_pm_resolve_cwd() {
  # Auto-detect project from current working directory
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1

  if [ -f "$REGISTRY" ]; then
    local result
    result=$(python3 -c "
import json, os, sys
with open('$REGISTRY') as f:
    reg = json.load(f)
repo_root = os.path.realpath(sys.argv[1])
for p in reg.get('projects', []):
    if os.path.realpath(os.path.expanduser(p['path'])) == repo_root:
        print(os.path.expanduser(p['path']) + '|' + p.get('metaBranch', 'meta/' + p['name']))
        break
" "$repo_root" 2>/dev/null || true)
    if [ -n "$result" ]; then
      IFS='|' read -r REPO_DIR META_BRANCH <<< "$result"
      return 0
    fi
  fi

  echo "No registered project found for $(pwd)" >&2
  return 1
}

if [ -n "${1:-}" ]; then
  _pm_resolve "$1"
else
  _pm_resolve_cwd
fi
