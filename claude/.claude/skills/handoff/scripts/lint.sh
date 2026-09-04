#!/usr/bin/env bash
# Deterministic checks on a handoff document. ERROR → exit 1 (fix and re-run); WARN → judgement call.
# Usage: lint.sh <handoff.md>
f=${1:?usage: lint.sh <handoff.md>}
[ -f "$f" ] || { echo "ERROR: $f not found"; exit 1; }
errors=0
err()  { echo "ERROR: $*"; errors=$((errors + 1)); }
warn() { echo "WARN:  $*"; }

for h in 'Goal' 'In Progress' 'Next Steps'; do
  grep -qE "^## $h( |$)" "$f" || err "missing mandatory section '## $h'"
done

lines=$(wc -l < "$f")
[ "$lines" -gt 100 ] && warn "$lines lines (target under 100) — cut what the code already says"

filler=$(grep -nE '^(None|N/A|n/a|Nothing)\.?$' "$f")
[ -n "$filler" ] && { warn "filler under an optional heading — drop the heading instead:"; echo "$filler" | sed 's/^/  /'; }

dead=$(grep -nE '/tmp/claude-|scratchpad' "$f")
[ -n "$dead" ] && { err "references the session scratchpad, which dies with the session — copy into claude_session/notes/sources/ and point there:"; echo "$dead" | sed 's/^/  /'; }

# Referenced paths should exist. Heuristic: tokens with a file extension, or a leading / ~/ ./ ../ prefix.
root=$(cd "$(dirname "$f")/../.." 2>/dev/null && pwd)
missing=""
while IFS= read -r p; do
  q=${p%%:*}; q=${q%%[.,;)]}; q=${q/#\~/$HOME}
  case "$q" in /*) t=$q ;; *) t="$root/$q" ;; esac
  [ -e "$t" ] || missing="$missing  $p"$'\n'
done < <(grep -oE '(^|[[:space:]`(])(~/|\.{1,2}/|/)?[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+(:[0-9]+)?' "$f" \
         | sed -E 's/^[[:space:]`(]//' | grep -E '^(/|~/|\./|\.\./)|/[^/]*\.[A-Za-z0-9]+(:[0-9]+)?$' \
         | grep -vE '^[A-Za-z0-9_-]+\.[A-Za-z0-9]+/' | sort -u)
[ -n "$missing" ] && { warn "referenced paths that don't exist (fine only if Next Steps creates them):"; printf '%s' "$missing"; }

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir "$f" --no-banner --log-level error >/dev/null 2>&1 || err "gitleaks flagged a secret — redact it"
fi

if [ "$errors" -eq 0 ]; then echo "lint: clean ($lines lines)"; else echo "lint: $errors error(s)"; fi
exit $(( errors > 0 ))
