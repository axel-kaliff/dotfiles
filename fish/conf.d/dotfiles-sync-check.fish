if test -f ~/.local/state/dotfiles-sync.log
    # Match the last status line, not the last raw line — git and stow output
    # is appended verbatim and would otherwise mask the outcome.
    set -l last_run (grep -E ' (OK|SKIP|ERROR|ABORT): ' ~/.local/state/dotfiles-sync.log 2>/dev/null | tail -1)
    if string match -qr 'ERROR|ABORT' -- $last_run
        set_color yellow
        echo "dotfiles sync stopped — check ~/.local/state/dotfiles-sync.log"
        set_color normal
    end
end

# Weekly health check. `just doctor` had never been run on a schedule, which is
# how gitleaks and pre-commit sat uninstalled while the config claimed otherwise.
# Only MISSING lines are printed, and only once a week, so it cannot nag.
if status is-interactive; and command -q just
    set -l stamp ~/.cache/dotfiles-doctor-stamp
    set -l now (date +%s)
    set -l last 0
    test -f $stamp; and set last (cat $stamp 2>/dev/null); or true
    string match -qr '^\d+$' -- "$last"; or set last 0

    if test (math $now - $last) -gt 604800
        mkdir -p (dirname $stamp); echo $now >$stamp
        set -l missing (just -f ~/dotfiles/justfile doctor 2>/dev/null | string match '*MISSING*')
        if test -n "$missing"
            set_color yellow
            echo "dotfiles doctor:"
            printf '  %s\n' $missing
            set_color normal
        end
    end
end
