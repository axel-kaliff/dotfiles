#!/usr/bin/env bash
# Regenerates claude_session/notes/INDEX.md from each note's header. Deterministic; safe to rerun.
# Usage: index.sh [project-dir]
proj=$1; [ -d "${proj:-}" ] || proj=$PWD
root=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || echo "$proj")
dir="$root/claude_session/notes"
[ -d "$dir" ] || { echo "no notes directory at $dir"; exit 1; }
{
  echo "# Notes index"
  echo
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f"); [ "$name" = INDEX.md ] && continue
    title=$(grep -m1 '^# ' "$f" | sed 's/^# //')
    q=$(grep -m1 '^- Question:' "$f" | sed 's/^- Question: *//')
    s=$(grep -m1 '^- Status:'   "$f" | sed 's/^- Status: *//')
    u=$(grep -m1 '^- Updated:'  "$f" | sed 's/^- Updated: *//')
    echo "- [${title:-$name}]($name) — ${q:-?} (${s:-?}, ${u:-?}, $(wc -l < "$f") lines)"
  done
  n=$(ls "$dir"/raw/*.md 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && { echo; echo "raw/: $n report(s) — \`ls claude_session/notes/raw/\`"; }
} > "$dir/INDEX.md"
cat "$dir/INDEX.md"
