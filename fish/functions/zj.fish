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
            case ide
                _zj_ide $argv[2..]
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
                ssh $host -t 'for z in "$HOME/.linuxbrew/bin/zellij" /home/linuxbrew/.linuxbrew/bin/zellij; do [ -x "$z" ] && exec "$z" attach -c '$session'; done; command -v zellij >/dev/null && exec zellij attach -c '$session'; echo "zellij not found on '$host'" >&2; exit 1'
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

# IDE session for a branch worktree: claude + neogit + shell (layouts/ide.kdl)
# Usage: zj ide [name] | zj ide done <name>
function _zj_ide
    if test "$argv[1]" = done
        _zj_ide_done $argv[2]
        return
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"
        echo "zj ide: not inside a git repository" >&2
        return 1
    end

    set -l tab (printf '\t')
    set -l name $argv[1]
    set -l wt
    if test -z "$name"
        # No name: pick an existing worktree (same row format as gwt)
        set -l rows (git worktree list | string replace -r '^(\S+) +\S+ +[\[(](.+)[\])]$' "\$2$tab\$1")
        set -l pick (printf '%s\n' $rows | fzf --height 40% --reverse --delimiter $tab \
            --preview 'git -C {2} log --oneline -10')
        or return
        set name (string split -f1 $tab -- $pick)
        set wt (string split -f2 $tab -- $pick)
    else
        set wt "$repo_root/.worktrees/$name"
        if not test -d $wt
            # Probe a child path: a dir-only pattern like `.worktrees/` never
            # matches the directory itself before it exists
            if not git check-ignore -q "$repo_root/.worktrees/probe"
                echo "zj ide: warning — .worktrees is not git-ignored" >&2
            end
            if git -C $repo_root show-ref --verify -q "refs/heads/$name"
                git -C $repo_root worktree add $wt $name; or return 1
            else
                # New branch: cut from origin's default branch, like /new-feature-branch
                set -l default (git -C $repo_root symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | string replace 'origin/' '')
                if test -z "$default"
                    echo "zj ide: cannot resolve origin's default branch" >&2
                    return 1
                end
                git -C $repo_root fetch origin $default
                git -C $repo_root worktree add $wt -b $name "origin/$default"; or return 1
            end
        end
    end

    # zellij targets dislike / and . in names
    set -l session (string replace -ra '[./]' '_' $name)
    mkdir -p "$HOME/.cache/zellij-layouts"
    echo ide >"$HOME/.cache/zellij-layouts/$session"

    # ide.kdl panes carry no cwd — they inherit the directory the session is
    # created from, so the cd here is what pins the session to the worktree.
    if test -z "$ZELLIJ"
        pushd $wt
        zellij attach -c $session options --default-layout ide
        popd
    else
        if not zellij list-sessions -s 2>/dev/null | grep -qx -- $session
            pushd $wt
            zellij attach --create-background $session options --default-layout ide
            popd
        end
        zellij action switch-session $session
    end
end

function _zj_ide_done
    set -l name $argv[1]
    if test -z "$name"
        echo "Usage: zj ide done <name>" >&2
        return 1
    end
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"
        echo "zj ide: not inside a git repository" >&2
        return 1
    end
    set -l session (string replace -ra '[./]' '_' $name)
    # Killing the session from inside it would orphan the git cleanup below
    if test "$ZELLIJ_SESSION_NAME" = "$session"
        echo "zj ide: detach first — refusing to tear down the current session" >&2
        return 1
    end
    zellij kill-session $session 2>/dev/null
    zellij delete-session $session 2>/dev/null
    rm -f "$HOME/.cache/zellij-layouts/$session"
    # No --force anywhere: dirty worktrees and unmerged branches fail loudly
    git -C $repo_root worktree remove "$repo_root/.worktrees/$name"; or return 1
    git -C $repo_root branch -d $name
end
