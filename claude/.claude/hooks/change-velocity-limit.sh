#!/usr/bin/env bash
# PostToolUse hook: tracks how many distinct Python files have been modified.
# Only counts .py files — config/docs don't count toward the limit.
# PostToolUse exit 2 = feedback to Claude (cannot block).

WARN_THRESHOLD=15
HARD_LIMIT=25

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or non-Python
if [ -z "$file_path" ] || [[ "$file_path" != *.py ]]; then
  exit 0
fi

# Use session_id from hook input for reliable cross-invocation tracking
session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -n "$session_id" ]; then
  STATE_FILE="/tmp/claude_changed_files_${session_id:0:12}"
else
  STATE_FILE="/tmp/claude_changed_files_$(date +%Y%m%d)"
fi

# Track unique files
touch "$STATE_FILE"
if ! grep -qxF "$file_path" "$STATE_FILE" 2>/dev/null; then
  echo "$file_path" >> "$STATE_FILE"
fi

count=$(wc -l < "$STATE_FILE" | tr -d ' ')
count=$((count + 0))

if [ "$count" -gt "$HARD_LIMIT" ]; then
  echo "VELOCITY LIMIT: Modified $count .py files this session (limit: $HARD_LIMIT). Stop and review." >&2
  exit 2
elif [ "$count" -gt "$WARN_THRESHOLD" ]; then
  echo "VELOCITY WARNING: Modified $count .py files this session (limit: $HARD_LIMIT)." >&2
fi

exit 0
