#!/usr/bin/env bash
# Unified PreToolUse hook for Bash commands.
# Combines: block-dangerous-commands, check-worktree-venv, pre-format-commit
# Single jq parse instead of three separate shell spawns.
# Exit 0 = allow, Exit 2 = block.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -z "$command" ] && exit 0

# --- Block dangerous commands ---

# Catastrophic deletions
if echo "$command" | grep -qE 'rm\s+(-[rRf]+\s+)*(/|/\*|~|~/|\$HOME)'; then
  echo "BLOCKED: Catastrophic deletion detected: $command" >&2
  exit 2
fi
if echo "$command" | grep -qE 'rm\s+-[rRf]+\s+\.$'; then
  echo "BLOCKED: 'rm -rf .' detected: $command" >&2
  exit 2
fi

# Force push to main/master only
if echo "$command" | grep -qE 'git\s+push\s+.*(-f|--force)' && echo "$command" | grep -qE '\b(main|master)\b'; then
  echo "BLOCKED: Force push to main/master detected: $command" >&2
  exit 2
fi

# pip install outside venv
if echo "$command" | grep -qE 'pip\s+install' && [ -z "$VIRTUAL_ENV" ]; then
  echo "BLOCKED: pip install outside virtual environment. Activate a venv first." >&2
  exit 2
fi

# Destructive SQL
if echo "$command" | grep -iqE '(DROP\s+(TABLE|DATABASE)|TRUNCATE\s+|DELETE\s+FROM)'; then
  echo "BLOCKED: Destructive SQL detected: $command" >&2
  exit 2
fi

# Dangerous sudo
if echo "$command" | grep -qE 'sudo\s+(rm|pip)'; then
  echo "BLOCKED: Dangerous sudo command detected: $command" >&2
  exit 2
fi

# --- Pre-format staged files before git commit ---

if echo "$command" | grep -qE 'git\s+commit' && ! echo "$command" | grep -qE '\-\-amend'; then
  staged_py=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.py$')
  if [ -n "$staged_py" ]; then
    changed=0
    for f in $staged_py; do
      [ -f "$f" ] || continue
      if command -v black &> /dev/null; then
        black --quiet "$f" 2>/dev/null
      fi
      if command -v ruff &> /dev/null; then
        ruff check --fix --unfixable F401 "$f" 2>/dev/null
      fi
    done
    for f in $staged_py; do
      [ -f "$f" ] || continue
      if ! git diff --quiet "$f" 2>/dev/null; then
        changed=1
        break
      fi
    done
    if [ "$changed" -eq 1 ]; then
      echo "Pre-format: formatted staged files, re-staging..." >&2
      for f in $staged_py; do
        [ -f "$f" ] && git add "$f" 2>/dev/null
      done
    fi
  fi
fi

exit 0
