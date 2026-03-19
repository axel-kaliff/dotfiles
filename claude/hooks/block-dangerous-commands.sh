#!/usr/bin/env bash
# Pre-tool hook: blocks dangerous bash commands
# Exit 0 = allow, Exit 2 = block

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [ -z "$command" ]; then
  exit 0
fi

# Block catastrophic deletions — catches flag reordering, trailing slashes, globs
if echo "$command" | grep -qE 'rm\s+(-[rRf]+\s+)*(/|/\*|~|~/|\$HOME)'; then
  echo "BLOCKED: Catastrophic deletion detected: $command" >&2
  exit 2
fi
# Also catch rm -rf . (wipe current directory)
if echo "$command" | grep -qE 'rm\s+-[rRf]+\s+\.$'; then
  echo "BLOCKED: 'rm -rf .' detected: $command" >&2
  exit 2
fi

# Block force push (catches -f, --force, --force-with-lease to main/master)
if echo "$command" | grep -qE 'git\s+push\s+.*(-f|--force)'; then
  echo "BLOCKED: Force push detected: $command" >&2
  exit 2
fi

# Block pip install outside virtual environment
if echo "$command" | grep -qE 'pip\s+install' && [ -z "$VIRTUAL_ENV" ]; then
  echo "BLOCKED: pip install outside virtual environment. Activate a venv first." >&2
  exit 2
fi

# Block destructive SQL (case-insensitive)
if echo "$command" | grep -iqE '(DROP\s+(TABLE|DATABASE)|TRUNCATE\s+|DELETE\s+FROM)'; then
  echo "BLOCKED: Destructive SQL detected: $command" >&2
  exit 2
fi

# Block dangerous sudo commands
if echo "$command" | grep -qE 'sudo\s+(rm|pip)'; then
  echo "BLOCKED: Dangerous sudo command detected: $command" >&2
  exit 2
fi

exit 0
