#!/usr/bin/env bash
# Pre-tool hook: detects broken venv in git worktrees
# If .venv exists but shebangs point to a nonexistent python, recreate it.
# Exit 0 = allow (after fix), Exit 2 = block

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only act on commands that would use the venv
if [ -z "$command" ]; then
  exit 0
fi

# Skip if no .venv directory exists
if [ ! -d ".venv" ]; then
  exit 0
fi

# Skip if not a git worktree
if [ ! -f ".git" ]; then
  exit 0  # .git is a file (not dir) in worktrees
fi

# Check if venv python shebang is valid
venv_python=".venv/bin/python"
if [ ! -f "$venv_python" ]; then
  exit 0
fi

shebang=$(head -1 "$venv_python" 2>/dev/null | sed 's/^#!//')
if [ -n "$shebang" ] && [ ! -x "$shebang" ]; then
  echo "Worktree venv has broken shebang: $shebang" >&2
  echo "Recreating venv..." >&2
  rm -rf .venv
  uv venv --python 3.12 >&2 2>&1
  uv sync --all-groups >&2 2>&1
  uv run pre-commit install >&2 2>&1
  echo "Venv recreated successfully." >&2
fi

exit 0
