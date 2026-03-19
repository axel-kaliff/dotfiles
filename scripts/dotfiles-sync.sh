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

# Skip if human is actively editing
if ! git diff --quiet || ! git diff --cached --quiet; then
    log "SKIP: uncommitted changes"
    exit 0
fi

# Pull with rebase
if git pull --rebase --autostash >> "$LOGFILE" 2>&1; then
    log "OK: pull succeeded"
else
    log "ERROR: rebase failed, aborting"
    git rebase --abort 2>/dev/null || true
    exit 1
fi

# Deploy
if command -v just &>/dev/null; then
    just -f "$DOTFILES_DIR/justfile" deploy >> "$LOGFILE" 2>&1
    log "OK: deploy complete"
fi
