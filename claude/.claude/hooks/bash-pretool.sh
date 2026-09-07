#!/usr/bin/env bash
# Unified PreToolUse hook for Bash commands.
# Combines: block-dangerous-commands, check-worktree-venv, pre-format-commit
# Single jq parse instead of three separate shell spawns.
# Exit 0 = allow, Exit 2 = block.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

[ -z "$command" ] && exit 0

# --- Frozen paths (companion to protect-frozen.sh, which covers Edit/Write) ---
# Block shell writes to any path listed in <repo>/.claude/frozen-paths: sed -i, rm, mv, cp,
# tee, truncate, chmod, or a redirection into it. Reads stay allowed.
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$root" ] && [ -f "$root/.claude/frozen-paths" ]; then
  while IFS= read -r pat; do
    { [ -z "$pat" ] || [[ "$pat" == \#* ]]; } && continue
    lit=${pat%%[\*\?\[]*}          # literal prefix of the glob
    [ -n "$lit" ] || continue
    esc=$(printf '%s' "$lit" | sed 's/[][\.*^$/]/\\&/g')
    if echo "$command" | grep -qF -- "$lit" && \
       { echo "$command" | grep -qE '(^|[;&|[:space:]])(sed|rm|mv|cp|tee|truncate|chmod)([[:space:]]|$)' || \
         echo "$command" | grep -qE ">>?[[:space:]]*['\"]?$esc"; }; then
      echo "BLOCKED: command writes to frozen path '$lit' (.claude/frozen-paths)." >&2
      exit 2
    fi
  done < "$root/.claude/frozen-paths"
fi

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

# Force push to main/master only: a force flag and the branch on the same `git push` invocation
if echo "$command" | grep -oE 'git\s+push[^;&|]*' \
   | grep -E '(^|\s)(-[a-zA-Z]*f[a-zA-Z]*|--force(-with-lease|-if-includes)?(=\S*)?|\+\S+)(\s|$)' \
   | grep -qE '(^|[[:space:]:+/])(main|master)([[:space:]:]|$)'; then
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
