#!/usr/bin/env bash
# PostToolUse on Edit|Write|MultiEdit: after a .py file changes, run ruff and ty on it and hand
# the findings for that file only back to Claude as context. Silent when clean. Formatting is ai-dev's
# format-on-save hook; this one only reports what needs a real fix.
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[[ "$file" == *.py && -f "$file" ]] || exit 0
root=$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || dirname "$file")
cd "$root" || exit 0

bin() {
  local c="$1" p
  for p in "$root/.venv/bin/$c" ${VIRTUAL_ENV:+"$VIRTUAL_ENV/bin/$c"}; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  command -v "$c"
}

out=""
if ruff=$(bin ruff); then
  out+=$(timeout 20 "$ruff" check --no-fix --ignore I --output-format concise "$file" 2>&1 | grep -vE '^(All checks passed|Found [0-9]+ error|\[\*\])' || true)
fi
if ty=$(bin ty); then
  extra=(); [ -d "$root/src" ] && extra=(--extra-search-path src)
  out+=$'\n'$(timeout 25 "$ty" check --output-format concise "${extra[@]}" "$file" 2>&1 | grep -vE '^(All checks passed|Found [0-9]+ diagnostic)' || true)
fi
# Scope guarantee: only diagnostics located in the edited file pass through, whatever the tools
# print about anything else.
rel=${file#"$root"/}
esc=$(printf '%s' "$rel" | sed 's/[][\.*^$/]/\\&/g')
out=$(printf '%s' "$out" | grep -E "^(\./)?($esc|$(printf '%s' "$file" | sed 's/[][\.*^$/]/\\&/g')):[0-9]+:" | head -60 || true)
[ -z "$out" ] && exit 0
jq -n --arg ctx "ruff/ty findings for ${file#"$root"/} (fix before moving on):"$'\n'"$out" \
  '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
