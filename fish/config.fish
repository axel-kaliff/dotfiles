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

set -gx EDITOR nvim
set -gx VISUAL nvim

set -gx XDG_CONFIG_HOME "$HOME/.config/"

set -gx PATH $PATH "$HOME/.local/bin"
set -gx PATH $PATH "/home/linuxbrew/.linuxbrew/bin/"

# fzf configuration (uses fd for faster searches)
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'

# ripgrep config
set -gx RIPGREP_CONFIG_PATH "$HOME/.config/ripgrep/config"

# bat theme
set -gx BAT_THEME "Nord"

# zoxide (replaces z)
zoxide init fish | source

# direnv
direnv hook fish | source

atuin init fish | source
starship init fish | source

# WORK 
if [ -f '/var/home/akaliff/tarballs/google-cloud-sdk/path.fish.inc' ]; . '/var/home/akaliff/tarballs/google-cloud-sdk/path.fish.inc'; end

