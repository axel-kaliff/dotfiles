set fish_greeting

# Auto-start zellij — attach to "main" session (configured in zellij/config.kdl)
if status is-interactive; and not set -q ZELLIJ
    exec zellij
end

# Abbreviations (expand inline, show real command in history)
abbr -a g lazygit
abbr -a cat bat
abbr -a ls eza
abbr -a v nvim
abbr -a vi nvim
abbr -a vim nvim
abbr -a tm tmuxinator

function udot
    echo "Syncing dotfiles..."
    cd ~/dotfiles/
    git add -A
    git commit -m "Update dotfiles"
    git pull --rebase
    git push
    echo "Git synced."
    just stow-dotfiles
    echo "Dotfiles stowed."
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

function dc
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

fish_add_path "$HOME/.local/bin"
fish_add_path "/home/linuxbrew/.linuxbrew/bin"

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
if [ -f '/var/home/akaliff/tarballs/google-cloud-sdk/path.fish.inc' ]; . '/var/home/akaliff/tarballs/google-cloud-sdk/path.fish.inc' 2>/dev/null; end

