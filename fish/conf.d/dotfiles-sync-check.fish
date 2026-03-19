if test -f ~/.local/state/dotfiles-sync.log
    if tail -1 ~/.local/state/dotfiles-sync.log 2>/dev/null | string match -q '*ERROR*'
        set_color yellow
        echo "dotfiles sync error — check ~/.local/state/dotfiles-sync.log"
        set_color normal
    end
end
