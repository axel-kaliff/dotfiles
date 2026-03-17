function tssh -d 'SSH and attach to remote tmux session'
    if test (count $argv) -eq 0
        echo "Usage: tssh [ssh-args] host [session-name]"
        return 1
    end

    # Check if last arg looks like a session name (no dashes, after a host)
    # Default session name is "main"
    set -l session main
    set -l ssh_args $argv

    # If --session or -s is passed, extract it
    set -l i 1
    while test $i -le (count $argv)
        if test "$argv[$i]" = --session -o "$argv[$i]" = -s
            set -l next (math $i + 1)
            if test $next -le (count $argv)
                set session $argv[$next]
                set -e ssh_args[$next]
                set -e ssh_args[$i]
                break
            end
        end
        set i (math $i + 1)
    end

    # Call the ssh fish function (handles terminfo, nvim sync, etc.)
    # -t forces TTY allocation, required for tmux
    ssh -t $ssh_args "tmux new-session -A -s $session"
end
