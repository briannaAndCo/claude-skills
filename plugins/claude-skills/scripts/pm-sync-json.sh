#!/usr/bin/env bash
# pm-sync-json — Regenerate project.json from plan.md on the meta branch
# Usage: pm-sync-json <project-name-or-path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"

PLAN=$(git -C "$REPO_DIR" show "$META_BRANCH:plan.md" 2>/dev/null) || { echo "No meta branch found"; exit 1; }

# Extract fields
PROJECT_NAME=$(echo "$PLAN" | head -1 | sed 's/^# Plan: //')
REPO_URL=$(echo "$PLAN" | grep '^> Repository:' | sed 's/^> Repository: //' || true)
OBJECTIVE=$(echo "$PLAN" | sed -n '/^## Objective$/,/^##/{/^##/!p;}' | head -3 | tr '\n' ' ' | xargs)

# Build JSON using python for safety
python3 -c "
import json, sys

plan_text = sys.stdin.read()
streams = {}

in_table = False
for line in plan_text.split('\n'):
    if '| Stream' in line and '| Status' in line:
        in_table = True
        continue
    if in_table and line.startswith('|') and not line.startswith('|--'):
        parts = [p.strip() for p in line.split('|')[1:-1]]
        if len(parts) >= 4:
            name = parts[0]
            status = parts[1]
            # Handle both old (4-col) and new (5-col with Type) formats
            if len(parts) >= 5:
                stype = parts[2]
                blocked = parts[3]
                notes = parts[4] if len(parts) > 4 else ''
            else:
                stype = 'feature'
                blocked = parts[2]
                notes = parts[3] if len(parts) > 3 else ''

            blocked_list = [b.strip() for b in blocked.split(',') if b.strip() and b.strip() != '—']
            streams[name] = {
                'status': status,
                'type': stype,
                'blockedBy': blocked_list,
                'description': notes
            }
    elif in_table and not line.startswith('|'):
        in_table = False

result = {
    'name': '$PROJECT_NAME',
    'created': '',
    'repo': '$REPO_URL',
    'objective': '$OBJECTIVE',
    'streams': streams
}

# Try to preserve created date from existing project.json
import subprocess
try:
    existing = subprocess.run(
        ['git', '-C', '$REPO_DIR', 'show', '$META_BRANCH:project.json'],
        capture_output=True, text=True
    )
    if existing.returncode == 0:
        old = json.loads(existing.stdout)
        result['created'] = old.get('created', '')
except:
    pass

print(json.dumps(result, indent=2))
" <<< "$PLAN"
