#!/usr/bin/env bash
# project-tmux — stream launcher
#
# Each stream opens in a separate terminal tab with its own tmux session.
# tmux provides visual context: stream name, colored status bar, and
# status indicators — so streams are visually distinct at a glance.
#
# Usage:
#   pt open     <project>                  Show project status + stream picker
#   pt stream   <project> <stream>         Open a single stream
#   pt parallel <project> <s1> <s2> ...    Open multiple streams
#   pt list     <project>                  List active worktrees

set -euo pipefail

REGISTRY="$HOME/.claude/projects-registry.json"

# ---------------------------------------------------------------------------
# Stream identity colors (from Interlace design system)
# Maps stream type keywords to tmux color pairs (bg, fg)
# ---------------------------------------------------------------------------
stream_color() {
  local stream_name="$1"
  local repo_dir="${2:-}"
  local stream_type="feature"  # default

  # Try to detect type from stream plan on meta
  if [ -n "$repo_dir" ] && git -C "$repo_dir" show-ref --quiet refs/heads/meta 2>/dev/null; then
    local plan_content
    plan_content=$(git -C "$repo_dir" show meta:streams/"$stream_name"/plan.md 2>/dev/null || true)
    if echo "$plan_content" | grep -qi "bug\|fix\|defect"; then
      stream_type="bug"
    elif echo "$plan_content" | grep -qi "refactor\|cleanup\|restructur"; then
      stream_type="refactor"
    elif echo "$plan_content" | grep -qi "research\|investigate\|spike\|explore"; then
      stream_type="research"
    elif echo "$plan_content" | grep -qi "ops\|deploy\|infra\|ci\|pipeline\|devops"; then
      stream_type="ops"
    fi
  fi

  # Return tmux color based on type
  # Using 256-color approximations of the Interlace palette
  case "$stream_type" in
    feature)  echo "colour24"  ;;  # #1A4A80 → deep blue
    bug)      echo "colour124" ;;  # #7A3020 → deep red
    refactor) echo "colour55"  ;;  # #4A2080 → purple
    research) echo "colour130" ;;  # #6A4010 → amber/brown
    ops)      echo "colour28"  ;;  # #0A4820 → deep green
    *)        echo "colour24"  ;;
  esac
}

# Stream status → indicator symbol
status_indicator() {
  local status="$1"
  case "$status" in
    in-progress) echo "● active"      ;;
    unblocked)   echo "○ ready"       ;;
    blocked)     echo "✕ blocked"     ;;
    complete)    echo "✓ complete"    ;;
    planned)     echo "◌ planned"     ;;
    on-hold)     echo "⏸ on-hold"    ;;
    *)           echo "? $status"     ;;
  esac
}

# Look up stream status from meta plan.md
get_stream_status() {
  local repo_dir="$1"
  local stream_name="$2"
  if git -C "$repo_dir" show-ref --quiet refs/heads/meta 2>/dev/null; then
    git -C "$repo_dir" show meta:plan.md 2>/dev/null \
      | grep "| $stream_name " \
      | head -1 \
      | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}'
  fi
}

# Get stream's one-line description from plan.md Notes column
get_stream_notes() {
  local repo_dir="$1"
  local stream_name="$2"
  if git -C "$repo_dir" show-ref --quiet refs/heads/meta 2>/dev/null; then
    git -C "$repo_dir" show meta:plan.md 2>/dev/null \
      | grep "| $stream_name " \
      | head -1 \
      | awk -F'|' '{gsub(/^ +| +$/, "", $5); print $5}'
  fi
}

# ---------------------------------------------------------------------------
# Resolve project path
# ---------------------------------------------------------------------------
resolve_project() {
  local input="$1"

  if [ -d "$input/.git" ] || [ -d "$input" ]; then
    echo "$input"
    return
  fi

  if [ -f "$REGISTRY" ]; then
    local path
    path=$(python3 -c "
import json, os
with open('$REGISTRY') as f:
    reg = json.load(f)
for p in reg.get('projects', []):
    if p['name'] == '$input':
        print(os.path.expanduser(p['path']))
        break
" 2>/dev/null || true)
    if [ -n "$path" ] && [ -d "$path" ]; then
      echo "$path"
      return
    fi
  fi

  echo "Project not found: $input" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Detect terminal
# ---------------------------------------------------------------------------
detect_terminal() {
  if osascript -e 'tell application "System Events" to (name of processes) contains "iTerm2"' 2>/dev/null | grep -q true; then
    echo "iTerm2"
  else
    echo "Terminal"
  fi
}

# ---------------------------------------------------------------------------
# Open a new terminal tab and run a command
# ---------------------------------------------------------------------------
open_tab() {
  local run="$1"
  local term
  term="$(detect_terminal)"

  # Write command to a temp script to avoid AppleScript string escaping issues
  local tmp_script
  tmp_script="$(mktemp /tmp/pt-launch-XXXXXXXX)"
  cat > "$tmp_script" <<SCRIPT
#!/usr/bin/env bash
$run
SCRIPT
  chmod +x "$tmp_script"

  if [ "$term" = "iTerm2" ]; then
    osascript - "$tmp_script" <<'APPLESCRIPT'
on run argv
  set theScript to item 1 of argv
  tell application "iTerm2"
    tell current window
      create tab with default profile
      tell current session
        write text theScript
      end tell
    end tell
  end tell
end run
APPLESCRIPT
  else
    osascript - "$tmp_script" <<'APPLESCRIPT'
on run argv
  set theScript to item 1 of argv
  tell application "Terminal"
    do script theScript
  end tell
end run
APPLESCRIPT
  fi
}

# ---------------------------------------------------------------------------
# Ensure a git worktree exists at .worktrees/<stream-name>
# ---------------------------------------------------------------------------
ensure_worktree() {
  local repo_dir="$1"
  local stream_name="$2"
  local branch="stream/$stream_name"
  local worktree_dir="$repo_dir/.worktrees/$stream_name"

  if [ ! -d "$repo_dir/.git" ]; then
    echo "No git repo found at $repo_dir" >&2
    exit 1
  fi

  if [ -f "$repo_dir/.gitignore" ]; then
    if ! grep -q '\.worktrees' "$repo_dir/.gitignore" 2>/dev/null; then
      echo '.worktrees' >> "$repo_dir/.gitignore"
    fi
  else
    echo '.worktrees' > "$repo_dir/.gitignore"
  fi

  if [ -d "$worktree_dir" ]; then
    echo "$worktree_dir"
    return
  fi

  mkdir -p "$repo_dir/.worktrees"

  if git -C "$repo_dir" show-ref --quiet "refs/heads/$branch"; then
    git -C "$repo_dir" worktree add "$worktree_dir" "$branch" >&2
  else
    git -C "$repo_dir" worktree add -b "$branch" "$worktree_dir" main >&2
  fi

  echo "$worktree_dir"
}

# ---------------------------------------------------------------------------
# Write CLAUDE.md to worktree root
# ---------------------------------------------------------------------------
write_stream_context() {
  local repo_dir="$1"
  local stream_name="$2"
  local worktree_dir="$3"

  local project_objective=""
  local project_name=""
  if git -C "$repo_dir" show-ref --quiet refs/heads/meta; then
    project_name=$(git -C "$repo_dir" show meta:plan.md 2>/dev/null | head -1 | sed 's/^# Plan: //')
    project_objective=$(git -C "$repo_dir" show meta:plan.md 2>/dev/null | sed -n '/^## Objective$/,/^##/p' | sed '1d;$d')
  fi

  local stream_plan=""
  if git -C "$repo_dir" show meta:streams/"$stream_name"/plan.md &>/dev/null; then
    stream_plan=$(git -C "$repo_dir" show meta:streams/"$stream_name"/plan.md)
  fi

  cat > "$worktree_dir/CLAUDE.md" <<CLAUDEMD
# Stream: ${stream_name}

## Project: ${project_name}
${project_objective}

## This Stream
${stream_plan}

## Context
- Worktree: ${worktree_dir}
- Branch: stream/${stream_name}
- Base: main
- Repo: ${repo_dir}

## Instructions
- Work only within this worktree
- Commit on branch stream/${stream_name}
- Do not modify files outside this stream's scope
- Follow codebase conventions
- When done, signal readiness for review

## On Start
1. Read this stream's plan above
2. Read relevant project context from the meta branch if needed:
   \`git show meta:design.md\`, \`git show meta:requirements.md\`, etc.
3. If the plan has an Approach and Tasks section, begin implementation
4. If the plan only has high-level AC, run the stream design pass first:
   explore the codebase, ask clarifying questions, propose approach,
   refine AC, break into tasks — then present for approval before coding
CLAUDEMD
}

# ---------------------------------------------------------------------------
# Open a single stream in a new terminal tab with tmux context bar
# ---------------------------------------------------------------------------
open_stream() {
  local repo_dir="$1"
  local stream_name="$2"
  local project_name
  project_name="$(basename "$repo_dir")"
  local session_name="${project_name}--${stream_name}"

  local worktree_dir
  worktree_dir="$(ensure_worktree "$repo_dir" "$stream_name")"
  write_stream_context "$repo_dir" "$stream_name" "$worktree_dir"

  # If session already exists, just attach in a new tab
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Stream already running: $stream_name — attaching"
    open_tab "tmux attach-session -t $(printf '%q' "$session_name")"
    return
  fi

  # Get stream identity
  local color
  color="$(stream_color "$stream_name" "$repo_dir")"
  local status
  status="$(get_stream_status "$repo_dir" "$stream_name")"
  local indicator
  indicator="$(status_indicator "${status:-in-progress}")"
  local notes
  notes="$(get_stream_notes "$repo_dir" "$stream_name")"

  # Build tmux status bar content
  # Top bar: [indicator] STREAM-NAME — description
  # Color-coded by stream type
  local left_status="  ${indicator}"
  local center_status="${stream_name}"
  local right_status="${notes}  "

  # Create tmux session with styled status bar
  local tmux_cmd
  tmux_cmd="tmux new-session -s '${session_name}' -c '${worktree_dir}'"
  tmux_cmd+=" \\; set status on"
  tmux_cmd+=" \\; set status-position top"
  tmux_cmd+=" \\; set status-style 'bg=${color},fg=white,bold'"
  tmux_cmd+=" \\; set status-left '  ${indicator}  │'"
  tmux_cmd+=" \\; set status-left-length 20"
  tmux_cmd+=" \\; set status-right '│  ${notes}  '"
  tmux_cmd+=" \\; set status-right-length 80"
  tmux_cmd+=" \\; set status-justify centre"
  tmux_cmd+=" \\; set window-status-current-format ' ${stream_name} '"
  tmux_cmd+=" \\; set window-status-format ' ${stream_name} '"
  tmux_cmd+=" \\; send-keys 'claude --permission-mode plan start' Enter"

  open_tab "$tmux_cmd"
  echo "Opened stream: $stream_name ($indicator)"
}

# ---------------------------------------------------------------------------
# Open multiple streams in parallel
# ---------------------------------------------------------------------------
open_parallel() {
  local repo_dir="$1"
  shift
  local streams=("$@")

  if [ ${#streams[@]} -eq 0 ]; then
    echo "No streams specified."
    exit 1
  fi

  for stream_name in "${streams[@]}"; do
    open_stream "$repo_dir" "$stream_name"
    sleep 0.5
  done

  echo ""
  echo "Opened ${#streams[@]} streams in parallel."
}

# ---------------------------------------------------------------------------
# List active worktrees
# ---------------------------------------------------------------------------
list_worktrees() {
  local repo_dir="$1"
  echo "Active worktrees for $(basename "$repo_dir"):"
  git -C "$repo_dir" worktree list | grep '\.worktrees' || echo "  (none)"
}

# ---------------------------------------------------------------------------
# Show project status with stream picker
# ---------------------------------------------------------------------------
open_project() {
  local repo_dir="$1"

  if ! git -C "$repo_dir" show-ref --quiet refs/heads/meta; then
    echo "No meta branch found at $repo_dir — not a managed project."
    exit 1
  fi

  local plan
  plan=$(git -C "$repo_dir" show meta:plan.md)

  local objective
  objective=$(echo "$plan" | sed -n '/^## Objective$/,/^##/p' | sed '1d;$d' | head -3)

  echo ""
  echo "$(echo "$plan" | head -1)"
  echo "$objective"
  echo ""

  local actionable=()
  local actionable_status=()
  local actionable_notes=()
  local other_lines=()

  while IFS='|' read -r _ stream status blocked notes _; do
    stream=$(echo "$stream" | xargs)
    status=$(echo "$status" | xargs)
    blocked=$(echo "$blocked" | xargs)
    notes=$(echo "$notes" | xargs)

    [ -z "$stream" ] && continue
    [[ "$stream" == "Stream" ]] && continue
    [[ "$stream" == "-"* ]] && continue

    if [[ "$status" == "in-progress" || "$status" == "unblocked" ]]; then
      actionable+=("$stream")
      actionable_status+=("$status")
      actionable_notes+=("$notes")
    else
      other_lines+=("  $(printf '%-25s' "$stream") ($status)")
    fi
  done <<< "$plan"

  if [ ${#actionable[@]} -gt 0 ]; then
    echo "Ready to work on:"
    echo ""
    for i in "${!actionable[@]}"; do
      local num=$((i + 1))
      local ind
      ind="$(status_indicator "${actionable_status[$i]}")"
      printf "  %d. %s %-25s — %s\n" "$num" "$ind" "${actionable[$i]}" "${actionable_notes[$i]}"
    done
    echo ""
  fi

  if [ ${#other_lines[@]} -gt 0 ]; then
    echo "Other streams:"
    for line in "${other_lines[@]}"; do
      echo "$line"
    done
    echo ""
  fi

  echo "Enter a number to open a stream, or:"
  echo "  a    Open all actionable streams in parallel"
  echo "  n    Create a new stream"
  echo "  q    Quit"
  echo ""

  read -rp "> " choice

  case "$choice" in
    [0-9]*)
      local idx=$((choice - 1))
      if [ $idx -ge 0 ] && [ $idx -lt ${#actionable[@]} ]; then
        open_stream "$repo_dir" "${actionable[$idx]}"
      else
        echo "Invalid selection."
      fi
      ;;
    a)
      open_parallel "$repo_dir" "${actionable[@]}"
      ;;
    n)
      echo "Use the create-project skill to add a new stream."
      ;;
    q)
      exit 0
      ;;
    *)
      echo "Invalid selection."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
cmd="${1:-help}"

case "$cmd" in
  stream)
    repo_dir="$(resolve_project "${2:-}")"
    open_stream "$repo_dir" "${3:-}"
    ;;
  parallel)
    repo_dir="$(resolve_project "${2:-}")"
    shift 2
    open_parallel "$repo_dir" "$@"
    ;;
  open)
    repo_dir="$(resolve_project "${2:-}")"
    open_project "$repo_dir"
    ;;
  list)
    repo_dir="$(resolve_project "${2:-}")"
    list_worktrees "$repo_dir"
    ;;
  help|*)
    echo "project-tmux — stream launcher"
    echo ""
    echo "Usage:"
    echo "  pt open     <project>                  Show project status + stream picker"
    echo "  pt stream   <project> <stream>         Open stream in a new terminal tab"
    echo "  pt parallel <project> <s1> <s2> ...    Open multiple streams in tabs"
    echo "  pt list     <project>                  List active worktrees"
    echo ""
    echo "<project> can be an absolute path or a name from the projects registry."
    echo ""
    echo "Each stream opens in its own terminal tab with a tmux status bar at"
    echo "the top showing the stream name, status indicator, and description."
    echo "Colors are mapped from the Interlace design system by stream type:"
    echo "  Blue = feature | Red = bug | Purple = refactor"
    echo "  Amber = research | Green = ops"
    ;;
esac
