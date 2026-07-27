if test -f ~/.local/state/dotfiles-sync.log
    # Match the last status line, not the last raw line — git and stow output
    # is appended verbatim and would otherwise mask the outcome.
    set -l last_run (grep -E ' (OK|SKIP|ERROR): ' ~/.local/state/dotfiles-sync.log 2>/dev/null | tail -1)
    if string match -q '*ERROR*' -- $last_run
        set_color yellow
        echo "dotfiles sync error — check ~/.local/state/dotfiles-sync.log"
        set_color normal
    end
end
