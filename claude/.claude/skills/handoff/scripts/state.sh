#!/usr/bin/env bash
# Ground truth for a handoff. Injected into SKILL.md at invocation; the agent never runs it by hand.
# Usage: state.sh [project-dir]
proj=$1; [ -d "${proj:-}" ] || proj=$PWD
# Live git state is per-worktree; the handoff directory is anchored to the main repo root, which
# --git-common-dir resolves to identically from the main worktree and from any linked one. Without
# that split a handoff written in .worktrees/x is invisible to a session started at the repo root.
wt=$(git -C "$proj" rev-parse --show-toplevel 2>/dev/null || echo "$proj")
root=$wt
if common=$(git -C "$proj" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  root=$(dirname "$common")
fi
echo "Now: $(date '+%Y-%m-%d %H:%M')"
echo "Root: $root"
echo "Worktree: $wt"
if git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Branch: $(git -C "$wt" branch --show-current)"
  echo "HEAD: $(git -C "$wt" rev-parse --short HEAD)"
  echo "Status:";         git -C "$wt" status --short     | sed 's/^/  /'
  echo "Diff stat:";      git -C "$wt" diff --stat        | sed 's/^/  /'
  echo "Recent commits:"; git -C "$wt" log --oneline -10  | sed 's/^/  /'
  echo "Stashes:";        git -C "$wt" stash list         | sed 's/^/  /'
  echo "Worktrees:";      git -C "$wt" worktree list      | sed 's/^/  /'
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
