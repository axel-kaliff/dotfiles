#!/usr/bin/env bash
# SessionStart hook (startup|clear|compact): announce an active handoff and the notes index so a
# fresh session knows to /pickup without the user remembering. Plain stdout becomes context.
input=$(cat)
sid=$(echo "$input" | jq -r '.session_id // empty')
src=$(echo "$input" | jq -r '.source // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty'); [ -d "$cwd" ] || cwd=$PWD
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")

h=$(ls -t "$root"/claude_session/handoffs/*.md 2>/dev/null | head -1)
if [ -n "$h" ] && [ "$src" != compact ]; then
  taken=$(grep '^- Picked up:' "$h" | tail -1)
  case "$taken" in
    *"${sid:-NO-SESSION}"*) ;;   # this session already picked it up
    *)
      mins=$(( ($(date +%s) - $(stat -c %Y "$h")) / 60 ))
      if [ "$mins" -lt 60 ]; then age="${mins}m"; elif [ "$mins" -lt 2880 ]; then age="$((mins / 60))h"; else age="$((mins / 1440))d"; fi
      title=$(head -1 "$h" | sed 's/^# Handoff: //')
      extra=""; [ -n "$taken" ] && extra=" Already picked up once (${taken#- Picked up: }) — check before continuing."
      echo "Active handoff: ${h#"$root"/} — \"$title\", written $age ago. Use /pickup to continue it.$extra"
      ;;
  esac
fi

idx="$root/claude_session/notes/INDEX.md"
[ -f "$idx" ] && echo "Research notes for this project: ${idx#"$root"/} — read it before re-researching a topic."
exit 0
