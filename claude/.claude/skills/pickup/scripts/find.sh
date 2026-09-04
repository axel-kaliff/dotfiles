#!/usr/bin/env bash
# Finds the active handoff and prints it with the live git state. Injected into SKILL.md at invocation.
# Usage: find.sh [project-dir]
proj=$1; [ -d "${proj:-}" ] || proj=$PWD
root=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || echo "$proj")
dir="$root/claude_session/handoffs"
mapfile -t active < <(ls -t "$dir"/*.md 2>/dev/null)
legacy=""
for c in "$PWD/HANDOFF.md" "$root/HANDOFF.md"; do [ -f "$c" ] && { legacy=$c; break; }; done
if [ ${#active[@]} -eq 0 ] && [ -z "$legacy" ]; then
  echo "No handoff found under $dir (nor a legacy HANDOFF.md)."
  exit 0
fi
h=${active[0]:-$legacy}
echo "Active handoff: $h"
[ ${#active[@]} -gt 1 ] && { echo "Stale extras (offer to archive):"; printf '  %s\n' "${active[@]:1}"; }
[ -n "$legacy" ] && [ ${#active[@]} -gt 0 ] && echo "Legacy HANDOFF.md also present (archive it): $legacy"
taken=$(grep '^- Picked up:' "$h" | tail -1)
[ -n "$taken" ] && echo "Already picked up: ${taken#- Picked up: }"
echo
echo "----- $h -----"
cat "$h"
echo "----- end of handoff -----"
echo
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Live git: branch $(git -C "$root" branch --show-current) @ $(git -C "$root" rev-parse --short HEAD)"
  echo "Status:";         git -C "$root" status --short    | sed 's/^/  /'
  echo "Recent commits:"; git -C "$root" log --oneline -5  | sed 's/^/  /'
fi
idx="$root/claude_session/notes/INDEX.md"
[ -f "$idx" ] && { echo; echo "Notes index ($idx):"; sed 's/^/  /' "$idx"; }
exit 0
