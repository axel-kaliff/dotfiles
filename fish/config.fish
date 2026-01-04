# if status is-interactive
#     if not set -q TMUX
#         /home/linuxbrew/.linuxbrew/bin/tmuxinator main
#     end
# end

set fish_greeting

function g 
    lazygit
end

function tm
    tmuxinator $argv
end


function cat 
    bat $argv
end

function ls
    eza $argv
end

function vi -d 'vi alias for nvim'
    nvim $argv
end

function v -d 'vi alias for nvim'
    nvim $argv
end

function vim -d 'vi alias for nvim'
    nvim $argv
end

function udot
    echo "Committing all changes, pulling from remote, and pushing to remote..."
    cd ~/dotfiles/
    rsync -a ~/.config/tmuxinator ~/dotfiles/
    git add .
    git commit -m "Update dotfiles"
    git pull
    git push
    echo "Git repository updated."
    echo "Copying dotfiles to the local .config directory..."
    just overwrite-local-dotfiles
    echo "Local .config directory updated with dotfiles."

end


function dn
    if test (count $argv) -lt 1
        echo "Usage: new_devcontainer <project_name>"
        return 1
    end
    set project $argv[1]
    # Pass the current working directory to just via --cwd.
    just --justfile "$HOME/dotfiles/devcontainer/justfile" new-devcontainer $project
end

function du
    devcontainer up --mount "type=bind,source=$HOME/.config/nvim,target=/home/devuser/.config/nvim" --workspace-folder .
end

function db
    devcontainer exec --workspace-folder . bash
end

function df
    devcontainer exec --workspace-folder . fish
end

function de
    devcontainer exec --workspace-folder . nvim
end

function uva
    source .venv/bin/activate
end

function dr
    devcontainer up --mount "type=bind,source=$HOME/.config/nvim,target=/home/devuser/.config/nvim" --workspace-folder . --remove-existing-container
end

# bind \cs '__ethp_commandline_toggle_sudo.fish'
bind \cs '__ethp_commandline_toggle_sudo'

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

export EDITOR=nvim
export VISUAL=nvim

export XDG_CONFIG_HOME="$HOME/.config/"

export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin/"

atuin init fish | source
starship init fish | source
