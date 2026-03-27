#!/usr/bin/env bash
# pm-meta-edit — Safely edit files on the meta branch using a temporary worktree
#
# Usage:
#   pm-meta-edit <project> <commit-msg> <command> [args...]
#
# The <command> receives the worktree path as $1 and can modify files freely.
# Changes are committed to the meta branch. The user's working tree is never touched.
#
# Examples:
#   pm-meta-edit myproject "meta: update status" ./my-edit-script.sh
#   pm-meta-edit myproject "meta: log session" python3 -c "..."
#   pm-meta-edit myproject "meta: update plan" bash -c 'echo "new content" > "$1/plan.md"'
#
# The command can also be a function name if this script is sourced.
# For simple edits, use the built-in subcommands (see pm-meta-edit.sh --help).
#
# Built-in subcommands (no external command needed):
#   pm-meta-edit <project> --set-status <stream> <status>
#   pm-meta-edit <project> --session-start <stream>
#   pm-meta-edit <project> --session-end <stream> <duration> <summary>
#   pm-meta-edit <project> --append <file> <content>
#   pm-meta-edit <project> --write <file> <content>
#   pm-meta-edit <project> --sync-json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/pm-resolve.sh" "${1:-}"
shift  # consume project arg

# Create temporary worktree
META_WORK=$(mktemp -d "${TMPDIR:-/tmp}/meta-edit.XXXXXX")
trap 'git -C "$REPO_DIR" worktree remove --force "$META_WORK" 2>/dev/null; rm -rf "$META_WORK"' EXIT

git -C "$REPO_DIR" worktree add --quiet "$META_WORK" "$META_BRANCH" 2>/dev/null

# Dispatch built-in subcommands or external command
case "${1:-}" in
  --set-status)
    STREAM="$2"
    STATUS="$3"
    VALID_STATUSES="planned unblocked in-progress blocked complete on-hold"
    if ! echo "$VALID_STATUSES" | grep -qw "$STATUS"; then
      echo "Invalid status: $STATUS. Valid: $VALID_STATUSES" >&2; exit 1
    fi
    python3 - "$STREAM" "$STATUS" "$META_WORK" <<'PYEOF'
import sys, json, os

stream, new_status, workdir = sys.argv[1], sys.argv[2], sys.argv[3]

# Update plan.md
plan_path = os.path.join(workdir, 'plan.md')
with open(plan_path, 'r') as f:
    lines = f.readlines()

header_idx = None
has_type_col = False
for i, line in enumerate(lines):
    if '| Stream' in line and '| Status' in line:
        header_idx = i
        has_type_col = '| Type' in line
        break

if header_idx is None:
    print('No streams table found', file=sys.stderr); sys.exit(1)

completed_streams = set()
updated = False

for i, line in enumerate(lines):
    if i <= header_idx + 1 or not line.startswith('|'):
        continue
    parts = [p.strip() for p in line.split('|')[1:-1]]
    if len(parts) < 4:
        continue
    name = parts[0]
    status_idx = 1

    if name == stream:
        parts[status_idx] = new_status
        lines[i] = '| ' + ' | '.join(parts) + ' |\n'
        updated = True

    check = new_status if name == stream else parts[status_idx]
    if check == 'complete':
        completed_streams.add(name)

if not updated:
    print(f'Stream not found: {stream}', file=sys.stderr); sys.exit(1)

# Auto-unblock
if new_status == 'complete':
    blocked_idx = 3 if has_type_col else 2
    for i, line in enumerate(lines):
        if i <= header_idx + 1 or not line.startswith('|'):
            continue
        parts = [p.strip() for p in line.split('|')[1:-1]]
        if len(parts) < 4 or parts[0] == stream:
            continue
        if parts[1] != 'blocked':
            continue
        blockers = [b.strip() for b in parts[blocked_idx].split(',') if b.strip() and b.strip() != '\u2014']
        if blockers and all(b in completed_streams for b in blockers):
            parts[1] = 'unblocked'
            lines[i] = '| ' + ' | '.join(parts) + ' |\n'
            print(f'Auto-unblocked: {parts[0]}')

with open(plan_path, 'w') as f:
    f.writelines(lines)

# Update project.json
json_path = os.path.join(workdir, 'project.json')
if os.path.exists(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
    streams = data.get('streams', {})
    if stream in streams:
        streams[stream]['status'] = new_status
        if new_status == 'complete':
            done = {s for s, info in streams.items() if info.get('status') == 'complete'}
            for s, info in streams.items():
                if info.get('status') == 'blocked':
                    if all(b in done for b in info.get('blockedBy', [])):
                        info['status'] = 'unblocked'
                        print(f'Auto-unblocked (json): {s}')
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')

print(f'{stream} → {new_status}')
PYEOF
    COMMIT_MSG="pm: set $STREAM → $STATUS"
    ;;

  --session-start)
    STREAM="$2"
    NOW=$(date "+%Y-%m-%d %H:%M")
    TODAY=$(date "+%Y-%m-%d")
    # Append to stream session.md
    SFILE="$META_WORK/streams/$STREAM/session.md"
    if [ -f "$SFILE" ]; then
      printf "\n## %s\n\n### Session %s\n- **Status**: in-progress\n" "$TODAY" "$NOW" >> "$SFILE"
    fi
    # Append to project session.md
    PSFILE="$META_WORK/session.md"
    if [ -f "$PSFILE" ]; then
      printf "\n## %s\n\n### Session %s\n- **Streams**: %s\n- **Status**: in-progress\n" "$TODAY" "$NOW" "$STREAM" >> "$PSFILE"
    fi
    COMMIT_MSG="pm: session start — $STREAM"
    echo "Session started: $STREAM at $NOW"
    ;;

  --session-end)
    STREAM="$2"
    DURATION="$3"
    SUMMARY="${4:-}"
    NOW=$(date "+%Y-%m-%d %H:%M")
    TODAY=$(date "+%Y-%m-%d")
    # Append to stream hours.md
    HFILE="$META_WORK/streams/$STREAM/hours.md"
    if [ -f "$HFILE" ]; then
      # Insert before the **Total** line
      python3 -c "
import sys
stream, duration, summary, today, hfile = sys.argv[1:]
with open(hfile, 'r') as f:
    content = f.read()
new_row = f'| {today} | {duration} | {summary} |'
if '**Total**' in content:
    content = content.replace('**Total**', new_row + '\n\n**Total**')
else:
    content += '\n' + new_row + '\n'
with open(hfile, 'w') as f:
    f.write(content)
" "$STREAM" "$DURATION" "$SUMMARY" "$TODAY" "$HFILE"
    fi
    # Append to stream session.md
    SFILE="$META_WORK/streams/$STREAM/session.md"
    if [ -f "$SFILE" ]; then
      printf "\n### Session ended %s (%s)\n%s\n" "$NOW" "$DURATION" "$SUMMARY" >> "$SFILE"
    fi
    # Append to project tasks.md
    TFILE="$META_WORK/tasks.md"
    if [ -f "$TFILE" ]; then
      python3 -c "
import sys
stream, duration, summary, today, tfile = sys.argv[1:]
with open(tfile, 'r') as f:
    content = f.read()
new_row = f'| {today} | {stream} | {summary} | {duration} |'
# Insert before '## Totals'
if '## Totals' in content:
    content = content.replace('## Totals', new_row + '\n\n## Totals')
else:
    content += '\n' + new_row + '\n'
with open(tfile, 'w') as f:
    f.write(content)
" "$STREAM" "$DURATION" "$SUMMARY" "$TODAY" "$TFILE"
    fi
    COMMIT_MSG="pm: session end — $STREAM ($DURATION)"
    echo "Session ended: $STREAM — $DURATION"
    ;;

  --append)
    FILE="$2"
    CONTENT="$3"
    TARGET="$META_WORK/$FILE"
    mkdir -p "$(dirname "$TARGET")"
    echo "$CONTENT" >> "$TARGET"
    COMMIT_MSG="pm: append to $FILE"
    ;;

  --write)
    FILE="$2"
    CONTENT="$3"
    TARGET="$META_WORK/$FILE"
    mkdir -p "$(dirname "$TARGET")"
    echo "$CONTENT" > "$TARGET"
    COMMIT_MSG="pm: write $FILE"
    ;;

  --sync-json)
    bash "$SCRIPT_DIR/pm-sync-json.sh" "$REPO_DIR" > "$META_WORK/project.json"
    COMMIT_MSG="pm: sync project.json"
    echo "project.json regenerated"
    ;;

  --help|"")
    echo "pm-meta-edit — Safely edit files on the meta branch"
    echo ""
    echo "Usage: pm-meta-edit <project> <subcommand> [args...]"
    echo ""
    echo "Subcommands:"
    echo "  --set-status <stream> <status>              Update stream status"
    echo "  --session-start <stream>                    Log session start"
    echo "  --session-end <stream> <duration> <summary> Log session end + hours"
    echo "  --append <file> <content>                   Append to a meta file"
    echo "  --write <file> <content>                    Overwrite a meta file"
    echo "  --sync-json                                 Regenerate project.json"
    echo ""
    echo "Custom command:"
    echo "  pm-meta-edit <project> <commit-msg> <cmd> [args...]"
    echo "  The command receives the worktree path as \$1"
    exit 0
    ;;

  *)
    # External command mode: $1 = commit message, $2+ = command
    COMMIT_MSG="$1"
    shift
    "$@" "$META_WORK"
    ;;
esac

# Commit if there are changes
if [ -n "$(git -C "$META_WORK" status --porcelain 2>/dev/null)" ]; then
  git -C "$META_WORK" add -A >/dev/null 2>&1
  git -C "$META_WORK" commit -m "$COMMIT_MSG" --quiet 2>/dev/null
  echo "Committed to $META_BRANCH"
else
  echo "No changes to commit"
fi
