function reload -d 'Reload fish config and optionally reset the current zellij session'
    echo "Reloading fish config..."
    source ~/.config/fish/config.fish
    echo "Fish config reloaded."

    if set -q ZELLIJ_SESSION_NAME
        if test (count $argv) -gt 0; and test $argv[1] = "--zellij"
            echo "Resetting zellij session '$ZELLIJ_SESSION_NAME'..."
            zj reset $ZELLIJ_SESSION_NAME
        else
            echo "Inside zellij session '$ZELLIJ_SESSION_NAME'. Use 'reload --zellij' to also reset the zellij session."
        end
    end
end
