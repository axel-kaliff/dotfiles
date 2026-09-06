#!/usr/bin/env bash
# PreToolUse on Edit|Write|MultiEdit: refuse edits to paths listed in <repo>/.claude/frozen-paths
# (one shell glob per line, relative to the repo root). /experiment-loop uses it to keep the
# evaluator, data prep, and correctness checks out of the loop's reach. Exit 2 blocks.
input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
dir=$(dirname "$file"); while [ ! -d "$dir" ] && [ "$dir" != / ]; do dir=$(dirname "$dir"); done   # new files in new dirs
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
list="$root/.claude/frozen-paths"
[ -f "$list" ] || exit 0
rel=${file#"$root"/}
while IFS= read -r pat; do
  { [ -z "$pat" ] || [[ "$pat" == \#* ]]; } && continue
  # shellcheck disable=SC2254
  case "$rel" in
    $pat) echo "BLOCKED: $rel is frozen for this experiment loop (.claude/frozen-paths). The evaluator, data prep, and checks are not editable; change the hypothesis instead." >&2; exit 2 ;;
  esac
done < "$list"
exit 0
