#!/usr/bin/env bash
# Post-tool hook: reminds Claude to run tests after editing source files.
# Lightweight hint — not a full test runner.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] || [[ "$file_path" != *.py ]] && exit 0

# Find project root (same pattern as stop-quality-gate.sh)
project_root="$(pwd)"
d="$(pwd)"
while [ "$d" != "/" ]; do
  [ -f "$d/pyproject.toml" ] || [ -f "$d/setup.py" ] && { project_root="$d"; break; }
  d=$(dirname "$d")
done

# Check if the edited file is a test file
if [[ "$file_path" == *_test.py ]] || [[ "$file_path" == */test_*.py ]]; then
  echo "Edited test file: $file_path — consider running it to verify" >&2
  exit 0
fi

# Check if there's a corresponding test file
base_name=$(basename "$file_path" .py)
test_candidates=$(find "$project_root/tests/" -name "${base_name}_test.py" -o -name "test_${base_name}.py" 2>/dev/null | head -1)

if [ -n "$test_candidates" ]; then
  echo "Source file $base_name has tests at: $test_candidates — consider running after changes are complete" >&2
fi

exit 0
