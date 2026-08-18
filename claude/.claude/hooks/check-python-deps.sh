#!/usr/bin/env bash
# Post-tool hook: analyzes Python dependency health after requirements/pyproject changes.
# Runs: pipdeptree (conflicts only) + deptry (import analysis).
# Output is compact counts only — no verbose tree dumps.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only trigger on dependency-related files
case "$file_path" in
  *requirements*.txt|*pyproject.toml|*setup.py|*setup.cfg|*Pipfile) ;;
  *) exit 0 ;;
esac

[ ! -f "$file_path" ] && exit 0

# Require active venv
if [ -z "$VIRTUAL_ENV" ]; then
  exit 0
fi

project_dir=$(dirname "$file_path")
while [ "$project_dir" != "/" ]; do
  [ -f "$project_dir/pyproject.toml" ] || [ -f "$project_dir/setup.py" ] && break
  project_dir=$(dirname "$project_dir")
done

issues=""

# --- pipdeptree: conflicts only ---
if command -v pipdeptree &> /dev/null; then
  conflict_count=$(pipdeptree --warn fail 2>&1 | grep -ciE 'conflict|circular' || echo 0)
  conflict_count=$((conflict_count + 0))
  if [ "$conflict_count" -gt 0 ]; then
    issues+="  pipdeptree: $conflict_count dependency conflict(s)\n"
  fi

  total=$(pipdeptree --warn silence -f 2>/dev/null | grep -c '==' || echo 0)
  echo "deps: $total packages installed, $conflict_count conflicts" >&2
fi

# --- deptry: unused/missing/transitive ---
if command -v deptry &> /dev/null; then
  deptry_count=$( (cd "$project_dir" && deptry . 2>&1) | grep -c ':' || echo 0)
  deptry_count=$((deptry_count + 0))
  if [ "$deptry_count" -gt 0 ]; then
    issues+="  deptry: $deptry_count issue(s) [run 'deptry .' for details]\n"
  fi
fi

if [ -n "$issues" ]; then
  echo -e "$issues" >&2
  exit 2
fi

exit 0
