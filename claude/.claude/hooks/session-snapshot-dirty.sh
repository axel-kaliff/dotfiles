#!/usr/bin/env bash
# SessionStart hook: snapshot dirty Python files with content hashes so the
# stop hook can detect which files were actually modified during the session.
# Files dirty at session start AND further modified during the session will
# still be checked (hash mismatch).
snapshot="/tmp/claude-dirty-snapshot-$$.txt"
{
  git diff --name-only HEAD 2>/dev/null | grep '\.py$' || true
  git diff --cached --name-only 2>/dev/null | grep '\.py$' || true
} | sort -u | grep -v '^$' | while read -r f; do
  [ -f "$f" ] && echo "$(md5sum "$f" | cut -d' ' -f1) $f"
done > "$snapshot"

# Store path for the stop hook to find (most recent snapshot wins)
echo "$snapshot" > /tmp/claude-dirty-snapshot-path.txt
exit 0
