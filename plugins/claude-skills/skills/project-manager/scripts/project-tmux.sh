#!/usr/bin/env bash
# project-tmux.sh — tmux session manager for the project-manager skill
#
# Usage:
#   project-tmux.sh open     <project>                  Open project overview window
#   project-tmux.sh stream   <project> <stream>         Open a single stream with Claude
#   project-tmux.sh parallel <project> <s1> <s2> ...   Open multiple streams in parallel
#   project-tmux.sh attach   <project>                  Attach to an existing session
#   project-tmux.sh list                                List all active project sessions
#   project-tmux.sh kill     <project>                  Kill a project session

set -euo pipefail

PROJECTS_ROOT="${PROJECTS_ROOT:-$HOME/projects}"

# Read projects_root from config if present
CONFIG="$HOME/.claude-projects-config"
if [ -f "$CONFIG" ]; then
  configured_root=$(python3 -c "import json,os; d=json.load(open('$CONFIG')); print(os.path.expanduser(d.get('projects_root','~/projects')))" 2>/dev/null || true)
  [ -n "$configured_root" ] && PROJECTS_ROOT="$configured_root"
fi

cmd="${1:-help}"
project="${2:-}"
session_name="pm-${project}"

# Write a CLAUDE.md into a stream directory so Claude has instant context on start
write_stream_context() {
  local project="$1"
  local stream="$2"
  local stream_dir="$PROJECTS_ROOT/$project/streams/$stream"
  cat > "$stream_dir/CLAUDE.md" <<EOF
# Stream: $stream

**Project**: $project
**Stream directory**: $stream_dir

You are working on the \`$stream\` stream of the \`$project\` project.

Read \`plan.md\` to understand your objectives, tasks, and acceptance criteria before beginning any work.

When starting work, begin a session (note the start time). When done, save the session with \`save session\` or \`end session\`.
EOF
}

open_project() {
  local project_dir="$PROJECTS_ROOT/$project"
  if [ ! -d "$project_dir" ]; then
    echo "Project not found: $project_dir"
    exit 1
  fi
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -n "overview" -c "$project_dir"
    # Show the master plan on open
    tmux send-keys -t "$session_name:overview" "cat plan.md | less -R" Enter
  fi
  tmux attach-session -t "$session_name"
}

open_stream() {
  local stream="$3"
  local stream_dir="$PROJECTS_ROOT/$project/streams/$stream"
  if [ ! -d "$stream_dir" ]; then
    echo "Stream not found: $stream_dir"
    exit 1
  fi
  # Ensure project session exists
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -n "overview" -c "$PROJECTS_ROOT/$project"
  fi
  # Write stream context CLAUDE.md
  write_stream_context "$project" "$stream"
  # Create stream window if it doesn't already exist
  if ! tmux list-windows -t "$session_name" -F "#{window_name}" 2>/dev/null | grep -qx "$stream"; then
    tmux new-window -t "$session_name" -n "$stream" -c "$stream_dir"
    tmux send-keys -t "$session_name:$stream" "claude" Enter
  fi
  tmux select-window -t "$session_name:$stream"
  tmux attach-session -t "$session_name"
}

open_parallel() {
  shift 2
  local streams=("$@")
  if [ ${#streams[@]} -eq 0 ]; then
    echo "No streams specified."
    exit 1
  fi
  # Ensure project session exists
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -n "overview" -c "$PROJECTS_ROOT/$project"
  fi
  for stream in "${streams[@]}"; do
    local stream_dir="$PROJECTS_ROOT/$project/streams/$stream"
    if [ ! -d "$stream_dir" ]; then
      echo "Warning: stream not found, skipping: $stream_dir"
      continue
    fi
    write_stream_context "$project" "$stream"
    if ! tmux list-windows -t "$session_name" -F "#{window_name}" 2>/dev/null | grep -qx "$stream"; then
      tmux new-window -t "$session_name" -n "$stream" -c "$stream_dir"
      tmux send-keys -t "$session_name:$stream" "claude" Enter
    fi
  done
  # Focus first stream
  tmux select-window -t "$session_name:${streams[0]}"
  tmux attach-session -t "$session_name"
}

case "$cmd" in
  open)
    open_project
    ;;
  stream)
    open_stream "$@"
    ;;
  parallel)
    open_parallel "$@"
    ;;
  attach)
    tmux attach-session -t "$session_name"
    ;;
  list)
    tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^pm-" | sed 's/^pm-//' || echo "No active project sessions."
    ;;
  kill)
    tmux kill-session -t "$session_name" && echo "Session killed: $session_name"
    ;;
  help|*)
    echo "project-tmux.sh — tmux manager for project-manager"
    echo ""
    echo "Usage:"
    echo "  project-tmux.sh open     <project>               Open project overview"
    echo "  project-tmux.sh stream   <project> <stream>      Open stream with Claude"
    echo "  project-tmux.sh parallel <project> <s1> <s2>...  Open parallel streams"
    echo "  project-tmux.sh attach   <project>               Attach to session"
    echo "  project-tmux.sh list                             List active sessions"
    echo "  project-tmux.sh kill     <project>               Kill session"
    ;;
esac
