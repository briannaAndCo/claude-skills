#!/usr/bin/env bash
# pm-set-status — Update a stream's status in plan.md and project.json
# Usage: pm-set-status [project] <stream> <status>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="$HOME/.claude/projects-registry.json"

VALID_STATUSES="planned unblocked in-progress blocked complete on-hold"

# Determine args: detect if first arg is a project or a stream
if [ $# -lt 2 ]; then
  echo "Usage: pm-set-status [project] <stream> <status>"
  echo "Valid statuses: $VALID_STATUSES"
  exit 1
fi

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

if [ $# -ge 3 ]; then
  # Explicit project, stream, status
  source "$SCRIPT_DIR/pm-resolve.sh" "$1"
  STREAM="$2"
  STATUS="$3"
elif [ $# -eq 2 ]; then
  # Could be: <project> <stream> (missing status) OR <stream> <status> (auto-detect project)
  # Check if $2 is a valid status
  if echo "$VALID_STATUSES" | grep -qw "$2"; then
    # $1 is stream, $2 is status, auto-detect project
    source "$SCRIPT_DIR/pm-resolve.sh"
    STREAM="$1"
    STATUS="$2"
  else
    echo "Usage: pm-set-status [project] <stream> <status>"
    echo "Valid statuses: $VALID_STATUSES"
    exit 1
  fi
fi

# Validate status
if ! echo "$VALID_STATUSES" | grep -qw "$STATUS"; then
  echo "Invalid status: $STATUS"
  echo "Valid statuses: $VALID_STATUSES"
  exit 1
fi

# Save current branch and stash state
PREV_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
STASHED=0
if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
  git -C "$REPO_DIR" stash push -m "pm-set-status auto-stash" >/dev/null 2>&1
  STASHED=1
fi

# Checkout meta branch
git -C "$REPO_DIR" checkout "$META_BRANCH" --quiet 2>/dev/null

# Update plan.md
PLAN_FILE="$REPO_DIR/plan.md"
if [ -f "$PLAN_FILE" ]; then
  python3 -c "
import sys

stream = sys.argv[1]
new_status = sys.argv[2]
plan_file = sys.argv[3]

with open(plan_file, 'r') as f:
    lines = f.readlines()

# Find table format
header_idx = None
has_type_col = False
for i, line in enumerate(lines):
    if '| Stream' in line and '| Status' in line:
        header_idx = i
        has_type_col = '| Type' in line or '|Type' in line
        break

if header_idx is None:
    print('No streams table found in plan.md', file=sys.stderr)
    sys.exit(1)

updated = False
completed_stream = stream if new_status == 'complete' else None
completed_streams = set()

# First pass: update target stream, collect all complete streams
for i, line in enumerate(lines):
    if i <= header_idx + 1:  # skip header and separator
        continue
    if not line.startswith('|'):
        continue
    parts = [p.strip() for p in line.split('|')[1:-1]]
    if len(parts) < 4:
        continue
    name = parts[0]

    if name == stream:
        # Update this stream's status
        if has_type_col and len(parts) >= 5:
            parts[1] = new_status
        else:
            parts[1] = new_status
        lines[i] = '| ' + ' | '.join(parts) + ' |\n'
        updated = True

    # Track completed streams (including the one we just set)
    check_status = new_status if name == stream else parts[1]
    if check_status == 'complete':
        completed_streams.add(name)

if not updated:
    print(f'Stream not found: {stream}', file=sys.stderr)
    sys.exit(1)

# Second pass: auto-unblock streams whose blockers are all complete
if completed_stream:
    for i, line in enumerate(lines):
        if i <= header_idx + 1:
            continue
        if not line.startswith('|'):
            continue
        parts = [p.strip() for p in line.split('|')[1:-1]]
        if len(parts) < 4:
            continue
        name = parts[0]
        if name == stream:
            continue

        if has_type_col and len(parts) >= 5:
            status_idx = 1
            blocked_idx = 3
        else:
            status_idx = 1
            blocked_idx = 2

        if parts[status_idx] != 'blocked':
            continue

        blockers = [b.strip() for b in parts[blocked_idx].split(',') if b.strip() and b.strip() != chr(0x2014)]
        if not blockers:
            continue

        # Check if all blockers are complete
        if all(b in completed_streams for b in blockers):
            parts[status_idx] = 'unblocked'
            lines[i] = '| ' + ' | '.join(parts) + ' |\n'
            print(f'Auto-unblocked: {name}')

with open(plan_file, 'w') as f:
    f.writelines(lines)

print(f'Updated {stream} -> {new_status}')
" "$STREAM" "$STATUS" "$PLAN_FILE"
fi

# Update project.json if it exists
PROJECT_JSON_FILE="$REPO_DIR/project.json"
if [ -f "$PROJECT_JSON_FILE" ]; then
  python3 -c "
import json, sys

stream = sys.argv[1]
new_status = sys.argv[2]
json_file = sys.argv[3]

with open(json_file, 'r') as f:
    data = json.load(f)

streams = data.get('streams', {})
if stream in streams:
    streams[stream]['status'] = new_status

    # Auto-unblock if completing
    if new_status == 'complete':
        completed = {s for s, info in streams.items() if info.get('status') == 'complete'}
        for s, info in streams.items():
            if info.get('status') == 'blocked':
                blockers = info.get('blockedBy', [])
                if blockers and all(b in completed for b in blockers):
                    info['status'] = 'unblocked'
                    print(f'Auto-unblocked in project.json: {s}')

    with open(json_file, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print(f'Updated project.json: {stream} -> {new_status}')
else:
    print(f'Stream {stream} not found in project.json', file=sys.stderr)
" "$STREAM" "$STATUS" "$PROJECT_JSON_FILE"
fi

# Commit changes
git -C "$REPO_DIR" add -A >/dev/null 2>&1
git -C "$REPO_DIR" commit -m "pm: set $STREAM -> $STATUS" --quiet 2>/dev/null || true

# Return to previous branch
if [ -n "$PREV_BRANCH" ] && [ "$PREV_BRANCH" != "$META_BRANCH" ]; then
  git -C "$REPO_DIR" checkout "$PREV_BRANCH" --quiet 2>/dev/null
fi

# Pop stash if we stashed
if [ "$STASHED" -eq 1 ]; then
  git -C "$REPO_DIR" stash pop --quiet 2>/dev/null || true
fi
