#!/usr/bin/env bash
# PreToolUse hook: blocks hardcoded secrets in Write/Edit operations.
# Scans new content for API keys, tokens, passwords, and other credentials.
# Exit 0 = allow, Exit 2 = block.

input=$(cat)

# Extract the content being written — handles both Write (content) and Edit (new_string)
new_text=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

if [ -z "$new_text" ]; then
  exit 0
fi

# Check for hardcoded secrets: KEY/SECRET/TOKEN/PASSWORD = "long_value"
if echo "$new_text" | grep -qEi '(API_KEY|SECRET_KEY|ACCESS_KEY|AUTH_TOKEN|PRIVATE_KEY|PASSWORD|CLIENT_SECRET)\s*[=:]\s*["'"'"'][A-Za-z0-9_\-/.+]{16,}'; then
  echo "BLOCKED: Hardcoded secret detected. Use environment variables or a secrets manager." >&2
  exit 2
fi

# Check for AWS-style keys (AKIA...)
if echo "$new_text" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  echo "BLOCKED: AWS access key detected. Use environment variables." >&2
  exit 2
fi

# Check for common token patterns (ghp_, sk-, pk_, Bearer hardcoded)
if echo "$new_text" | grep -qE '(ghp_[A-Za-z0-9]{36}|sk-[A-Za-z0-9]{40,}|pk_live_[A-Za-z0-9]{20,})'; then
  echo "BLOCKED: API token detected (GitHub/OpenAI/Stripe). Use environment variables." >&2
  exit 2
fi

# Check for private key blocks
if echo "$new_text" | grep -q 'BEGIN.*PRIVATE KEY'; then
  echo "BLOCKED: Private key detected. Never embed keys in source code." >&2
  exit 2
fi

exit 0
