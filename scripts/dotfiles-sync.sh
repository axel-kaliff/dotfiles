#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
LOGFILE="$HOME/.local/state/dotfiles-sync.log"
LOCKFILE="/tmp/dotfiles-sync.lock"
NETWORK_WAIT_SECONDS=60

mkdir -p "$(dirname "$LOGFILE")"

# Prevent concurrent runs
exec 200>"$LOCKFILE"
flock -n 200 || { echo "$(date -Is) SKIP: already running" >> "$LOGFILE"; exit 0; }

log() { echo "$(date -Is) $1" >> "$LOGFILE"; }

# Persistent=true fires the timer the instant the user slice thaws after
# suspend, before NetworkManager has re-associated. Wait for the link instead
# of failing on unresolvable DNS.
wait_for_network() {
    if command -v nm-online &>/dev/null; then
        nm-online -q -t "$NETWORK_WAIT_SECONDS"
        return
    fi
    local deadline=$((SECONDS + NETWORK_WAIT_SECONDS))
    while ((SECONDS < deadline)); do
        getent hosts github.com &>/dev/null && return 0
        sleep 2
    done
    return 1
}

# Transport-level failures only — auth and rebase conflicts are real errors.
is_network_error() {
    grep -qiE 'could not resolve|name or service not known|network is unreachable|temporary failure in name resolution|connection timed out' <<<"$1"
}

cd "$DOTFILES_DIR"

if ! wait_for_network; then
    log "SKIP: offline after ${NETWORK_WAIT_SECONDS}s wait"
    exit 0
fi

# Tripwire: a wiped working tree (a bad stow/deploy, a half-restored home) must
# never be auto-committed and pushed — that is how one broken machine takes the
# dotfiles out everywhere else. Bulk deletions need a human.
MAX_AUTO_DELETIONS=25
deleted_count=$(git diff HEAD --diff-filter=D --name-only | wc -l)
if ((deleted_count > MAX_AUTO_DELETIONS)); then
    log "ABORT: $deleted_count deletions in the working tree (limit $MAX_AUTO_DELETIONS) — refusing to auto-commit."
    log "       Inspect: git -C $DOTFILES_DIR status"
    log "       Restore: git -C $DOTFILES_DIR restore ."
    exit 1
fi

# Auto-commit any local changes
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git add -A

    # The only secret scan in this path. The commit below is --no-verify (an
    # unattended timer cannot answer a hook prompt), and GitHub's free push
    # protection on public repos matches provider-prefixed tokens only — it
    # would not stop a config-style credential. Fails closed on purpose: a
    # machine without gitleaks must not auto-push to a public repo.
    if ! command -v gitleaks &>/dev/null; then
        git reset >/dev/null
        log "ABORT: gitleaks not installed — refusing to auto-commit to a public repo."
        log "       Install: brew install gitleaks"
        exit 1
    fi
    if ! scan_output=$(gitleaks git --pre-commit --staged --no-banner --redact \
        -c "$DOTFILES_DIR/.gitleaks.toml" 2>&1); then
        # Unstage only — the working tree is left exactly as the user left it.
        git reset >/dev/null
        printf '%s\n' "$scan_output" >> "$LOGFILE"
        log "ABORT: gitleaks flagged staged content — nothing committed or pushed."
        log "       Review: git -C $DOTFILES_DIR status"
        exit 1
    fi

    git commit -m "auto-sync from $(hostname) at $(date -Is)" --no-gpg-sign --no-verify
    log "OK: auto-committed local changes"
fi

# Pull with rebase (our auto-commits rebase cleanly on top of remote)
pull_status=0
pull_output=$(git pull --rebase --autostash 2>&1) || pull_status=$?
printf '%s\n' "$pull_output" >> "$LOGFILE"

if ((pull_status != 0)); then
    git rebase --abort 2>/dev/null || true
    if is_network_error "$pull_output"; then
        log "SKIP: network unavailable during pull"
        exit 0
    fi
    log "ERROR: rebase failed, aborting"
    exit 1
fi
log "OK: pull succeeded"

# Push if we have commits ahead of remote
if [ "$(git rev-list --count @{u}..HEAD 2>/dev/null)" -gt 0 ]; then
    push_status=0
    push_output=$(git push 2>&1) || push_status=$?
    printf '%s\n' "$push_output" >> "$LOGFILE"

    if ((push_status != 0)); then
        if is_network_error "$push_output"; then
            log "SKIP: network unavailable during push"
            exit 0
        fi
        log "ERROR: push failed"
        exit 1
    fi
    log "OK: push succeeded"
fi

# Deploy — recipe overridable per machine (the homeserver unit sets deploy-server)
if command -v just &>/dev/null; then
    if just -f "$DOTFILES_DIR/justfile" "${DOTFILES_DEPLOY_RECIPE:-deploy}" >> "$LOGFILE" 2>&1; then
        log "OK: deploy complete"
    else
        log "ERROR: deploy failed"
        exit 1
    fi
fi
