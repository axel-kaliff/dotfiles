#!/usr/bin/env bash
# Pre-tool hook: auto-formats staged Python files before git commit.
# Uses ruff (consistent with post-write hook). Exit 0 = allow.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only act on git commit commands
if ! echo "$command" | grep -qE 'git\s+commit'; then
  exit 0
fi

# Skip amend
if echo "$command" | grep -qE '\-\-amend'; then
  exit 0
fi

# Get staged Python files
staged_py=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.py$')
if [ -z "$staged_py" ]; then
  exit 0
fi

changed=0

for f in $staged_py; do
  [ -f "$f" ] || continue

  if command -v ruff &> /dev/null; then
    ruff format "$f" 2>/dev/null
    # Match post-write hook: fix all except F401 (runtime import protection)
    ruff check --fix --unfixable F401 "$f" 2>/dev/null
  fi
  if command -v black &> /dev/null; then
    black --quiet "$f" 2>/dev/null
  fi
done

# Check if any staged files were modified by formatting
for f in $staged_py; do
  [ -f "$f" ] || continue
  if ! git diff --quiet "$f" 2>/dev/null; then
    changed=1
    break
  fi
done

# Re-stage formatted files
if [ "$changed" -eq 1 ]; then
  echo "Pre-format: ruff fixed staged files, re-staging..." >&2
  for f in $staged_py; do
    [ -f "$f" ] && git add "$f" 2>/dev/null
  done
fi

exit 0
