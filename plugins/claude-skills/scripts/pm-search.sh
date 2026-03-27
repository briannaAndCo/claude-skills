#!/usr/bin/env bash
# pm-search — Search across all planning files on the meta branch
# Usage: pm-search <project-name-or-path> <query>
set -euo pipefail

if [ $# -lt 1 ]; then echo "Usage: pm-search [project] <query>"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$HOME/.claude/projects-registry.json"

_is_registered_project() {
  [ -f "$REGISTRY" ] || return 1
  python3 -c "
import json, sys
with open('$REGISTRY') as f:
    reg = json.load(f)
for p in reg.get('projects', []):
    if p['name'] == sys.argv[1]:
        sys.exit(0)
sys.exit(1)
" "$1" 2>/dev/null
}

if [ $# -ge 2 ]; then
  source "$SCRIPT_DIR/pm-resolve.sh" "$1"
  QUERY="$2"
elif [ $# -eq 1 ]; then
  source "$SCRIPT_DIR/pm-resolve.sh"
  QUERY="$1"
fi

# List all files on meta branch and grep through them
FILES=$(git -C "$REPO_DIR" ls-tree -r --name-only "$META_BRANCH" 2>/dev/null) || { echo "No meta branch found"; exit 1; }

echo "Searching for '$QUERY' across planning files..."
echo ""

echo "$FILES" | while read -r file; do
  matches=$(git -C "$REPO_DIR" show "$META_BRANCH:$file" 2>/dev/null | grep -in "$QUERY" || true)
  if [ -n "$matches" ]; then
    echo "=== $file ==="
    echo "$matches"
    echo ""
  fi
done
