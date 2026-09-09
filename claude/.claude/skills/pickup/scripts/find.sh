#!/usr/bin/env bash
# Finds the active handoff and prints it with the live git state. Injected into SKILL.md at invocation.
# Usage: find.sh [project-dir]
proj=$1; [ -d "${proj:-}" ] || proj=$PWD
# Anchor on the main repo root, which --git-common-dir resolves to identically from the main
# worktree and from any linked one, so a handoff written in .worktrees/x is found from anywhere.
wt=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || echo "$proj")
root=$wt
if common=$(git -C "$proj" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  root=$(dirname "$common")
fi
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
# Report live git for the worktree the handoff was written in, not the one this session happens to
# have started in — they differ whenever the previous session worked in .worktrees/.
hw=$(grep -m1 '^- Worktree:' "$h" | sed 's/^- Worktree:[[:space:]]*//; s/`//g')
tree=$wt
if [ -n "$hw" ] && [ -d "$hw" ] && [ "$hw" != "$wt" ]; then
  tree=$hw
  echo "Handoff worktree: $hw (this session started in $wt — cd there before working)"
elif [ -n "$hw" ] && [ ! -d "$hw" ]; then
  echo "Handoff worktree: $hw — GONE (removed since the handoff; treat its Next Steps as suspect)"
fi
if git -C "$tree" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Live git in $tree: branch $(git -C "$tree" branch --show-current) @ $(git -C "$tree" rev-parse --short HEAD)"
  echo "Status:";         git -C "$tree" status --short    | sed 's/^/  /'
  echo "Recent commits:"; git -C "$tree" log --oneline -5  | sed 's/^/  /'
  echo "Worktrees:";      git -C "$tree" worktree list     | sed 's/^/  /'
fi
idx="$root/claude_session/notes/INDEX.md"
[ -f "$idx" ] && { echo; echo "Notes index ($idx):"; sed 's/^/  /' "$idx"; }
exit 0
