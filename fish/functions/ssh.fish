function ssh --wraps ssh
    # Extract hostname from args (skip flags and their values)
    set -l host ""
    set -l skip_next false
    for arg in $argv
        if $skip_next
            set skip_next false
            continue
        end
        switch $arg
            case '-*'
                # Flags that take a value
                switch $arg
                    case -b -c -D -E -e -F -I -i -J -L -l -m -O -o -p -Q -R -S -W -w
                        set skip_next true
                end
            case '*'
                set host $arg
                break
        end
    end

    # If we couldn't parse a host, just pass through
    if test -z "$host"
        command ssh $argv
        return
    end

    # Sync neovim config to r2d2 before connecting
    if test "$host" = r2d2
        echo "Syncing nvim config to r2d2..."
        rsync -az --delete "$HOME/.config/nvim/" "r2d2:.config/nvim/" 2>/dev/null
        or echo "Warning: nvim config sync failed"
    end

    # Copy Ghostty terminfo if needed
    if test "$TERM" = xterm-ghostty
        set -l cache_dir "$HOME/.cache/ghostty-ssh"
        set -l marker "$cache_dir/$host"

        if not test -f "$marker"
            echo "Copying Ghostty terminfo to $host..."
            if infocmp -x 2>/dev/null | command ssh $argv -- tic -x - 2>/dev/null
                mkdir -p "$cache_dir"
                touch "$marker"
            end
        end
    end

    command ssh $argv
end
