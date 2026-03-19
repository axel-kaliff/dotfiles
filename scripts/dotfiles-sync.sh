#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
LOGFILE="$HOME/.local/state/dotfiles-sync.log"
LOCKFILE="/tmp/dotfiles-sync.lock"

mkdir -p "$(dirname "$LOGFILE")"

# Prevent concurrent runs
exec 200>"$LOCKFILE"
flock -n 200 || { echo "$(date -Is) SKIP: already running" >> "$LOGFILE"; exit 0; }

log() { echo "$(date -Is) $1" >> "$LOGFILE"; }

cd "$DOTFILES_DIR"

# Auto-commit any local changes
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git add -A
    git commit -m "auto-sync from $(hostname) at $(date -Is)" --no-gpg-sign
    log "OK: auto-committed local changes"
fi

# Pull with rebase (our auto-commits rebase cleanly on top of remote)
if git pull --rebase --autostash >> "$LOGFILE" 2>&1; then
    log "OK: pull succeeded"
else
    log "ERROR: rebase failed, aborting"
    git rebase --abort 2>/dev/null || true
    exit 1
fi

# Push if we have commits ahead of remote
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" -gt 0 ]; then
    if git push >> "$LOGFILE" 2>&1; then
        log "OK: push succeeded"
    else
        log "ERROR: push failed"
        exit 1
    fi
fi

# Deploy
if command -v just &>/dev/null; then
    just -f "$DOTFILES_DIR/justfile" deploy >> "$LOGFILE" 2>&1
    log "OK: deploy complete"
fi
