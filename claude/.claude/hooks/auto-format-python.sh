#!/usr/bin/env bash
# Post-tool hook: SILENTLY formats Python files after Edit/Write.
# Only action: black format + ruff auto-fix + copyright fix. Zero output.
# All violation reporting happens in the Stop hook, not here.
# This prevents repeated output from eating context on every edit.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or non-Python or missing
if [ -z "$file_path" ] || [[ "$file_path" != *.py ]] || [ ! -f "$file_path" ]; then
  exit 0
fi

# Copyright header fix
sed -i 's/(C) 2026 sics.ai/© 2026 sics.ai/g; s/(C) 2025 sics.ai/© 2025 sics.ai/g' "$file_path" 2>/dev/null

# Black for formatting, ruff for auto-fixable lint violations (no ruff format)
if command -v black &> /dev/null; then
  black --quiet "$file_path" 2>/dev/null
fi
if command -v ruff &> /dev/null; then
  ruff check --fix --unfixable F401 "$file_path" 2>/dev/null
fi

exit 0
