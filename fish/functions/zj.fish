function zj -d 'Zellij session helper'
    if test (count $argv) -eq 0
        # No args: use current directory basename as session name
        set -l session_name (basename (pwd))
        zellij attach -c $session_name
    else
        switch $argv[1]
            case ls
                zellij list-sessions
            case kill
                zellij kill-session $argv[2..]
            case attach a
                zellij attach -c $argv[2]
            case layout
                # Start a session with a layout, recording the layout name
                set -l session $argv[2]
                set -l layout $argv[3]
                mkdir -p "$HOME/.cache/zellij-layouts"
                echo $layout >"$HOME/.cache/zellij-layouts/$session"
                zellij attach -c $session options --default-layout $layout
            case reset
                # Kill and re-launch a session with its original layout
                set -l session $argv[2]
                if test -z "$session"
                    echo "Usage: zj reset <session>"
                    return 1
                end
                # Look up stored layout, fall back to session name
                set -l layout_file "$HOME/.cache/zellij-layouts/$session"
                set -l layout $session
                if test -f "$layout_file"
                    set layout (cat "$layout_file")
                end
                zellij kill-session $session 2>/dev/null
                zellij delete-session $session 2>/dev/null
                echo "Restarting session '$session' with layout '$layout'..."
                zellij attach -c $session options --default-layout $layout
            case remote
                # Connect to a remote Zellij session over SSH
                # Usage: zj remote [host] [session]
                set -l host (test -n "$argv[2]" && echo $argv[2] || echo r2d2)
                set -l session (test -n "$argv[3]" && echo $argv[3] || echo main)
                # Lock local zellij so keybinds pass through to remote
                if test -n "$ZELLIJ"
                    zellij action switch-mode locked
                end
                ssh $host -t '$HOME/.linuxbrew/bin/zellij attach -c '$session
                # Unlock local zellij after disconnect
                if test -n "$ZELLIJ"
                    zellij action switch-mode normal
                end
            case web
                # Open SSH tunnel to remote Zellij web server
                # Usage: zj web [host] [port]
                set -l host (test -n "$argv[2]" && echo $argv[2] || echo r2d2)
                set -l port (test -n "$argv[3]" && echo $argv[3] || echo 8082)
                echo "Tunneling $host:$port -> localhost:$port"
                echo "Open http://localhost:$port in your browser"
                ssh -N -L $port:127.0.0.1:$port $host
            case '*'
                zellij attach -c $argv[1]
        end
    end
end
