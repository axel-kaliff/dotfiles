function zj -d 'Zellij session helper'
    if test (count $argv) -eq 0
        zellij list-sessions
    else
        switch $argv[1]
            case ls
                zellij list-sessions
            case kill
                zellij kill-session $argv[2..]
            case attach a
                zellij attach -c $argv[2]
            case '*'
                # zj <name> → attach or create session with that name
                zellij attach -c $argv[1]
        end
    end
end
