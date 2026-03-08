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
                zellij attach -c $argv[2] options --layout $argv[3]
            case '*'
                zellij attach -c $argv[1]
        end
    end
end
