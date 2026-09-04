#!/usr/bin/env bash
# Ground truth for a handoff. Injected into SKILL.md at invocation; the agent never runs it by hand.
# Usage: state.sh [project-dir]
proj=$1; [ -d "${proj:-}" ] || proj=$PWD
root=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || echo "$proj")
echo "Now: $(date '+%Y-%m-%d %H:%M')"
echo "Root: $root"
if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Branch: $(git -C "$root" branch --show-current)"
  echo "HEAD: $(git -C "$root" rev-parse --short HEAD)"
  echo "Status:";         git -C "$root" status --short     | sed 's/^/  /'
  echo "Diff stat:";      git -C "$root" diff --stat        | sed 's/^/  /'
  echo "Recent commits:"; git -C "$root" log --oneline -10  | sed 's/^/  /'
  echo "Stashes:";        git -C "$root" stash list         | sed 's/^/  /'
else
  echo "Git: none"
fi
slug=$(printf '%s' "$proj" | sed 's/[^A-Za-z0-9]/-/g')
echo "Session: ${CLAUDE_CODE_SESSION_ID:-unknown}"
echo "Transcript: ~/.claude/projects/$slug/${CLAUDE_CODE_SESSION_ID:-unknown}.jsonl"
echo "Active handoffs:"; ls -t "$root"/claude_session/handoffs/*.md 2>/dev/null | sed 's/^/  /'
[ -f "$root/claude_session/DECISIONS.md" ] && echo "DECISIONS.md: present"
if [ -f "$root/claude_session/notes/INDEX.md" ]; then
  echo "Notes index:"; sed 's/^/  /' "$root/claude_session/notes/INDEX.md"
fi
exit 0
