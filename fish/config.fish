if status is-interactive
    # Commands to run in interactive sessions can go here
end

set fish_greeting

function g 
    lazygit
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
    git add .
    git commit -m "Update dotfiles"
    git pull
    git push
    echo "Git repository updated."
    echo "Copying dotfiles to the local .config directory..."
    just overwrite-local-dotfiles
    echo "Local .config directory updated with dotfiles."

end

# TODO replace with topgrade
# function update -d "update apt, flatpak, fish"
#
#     echo 'Updating apt...'
#
#     sudo apt-get update -y
#     sudo apt-get upgrade -y
#     sudo apt-get autoclean -y
#
#     echo 'Updating flatpaks...'
#     sudo flatpak update -y
#
#     echo 'Updating fish...'
#     fisher update
#
#     exit 0
#
# end



function new_devcontainer
    if test (count $argv) -lt 1
        echo "Usage: new_devcontainer <project_name>"
        return 1
    end
    set project $argv[1]
    # Pass the current working directory to just via --cwd.
    just --cwd (pwd) --justfile "$HOME/dotfiles/devcontainer/justfile" new-devcontainer $project
end




# bind \cs '__ethp_commandline_toggle_sudo.fish'
bind \cs '__ethp_commandline_toggle_sudo'


export EDITOR=nvim

export PATH="$PATH:$HOME/.local/bin"

export PATH="$PATH:/opt/nvim-linux64/bin"
export PATH="$HOME/tools/node-v14.15.4-linux-x64/bin:$PATH"

# GO
export PATH="$PATH:/usr/local/go/bin"

export GOPATH="$USER/home/go"
alias golint="$GOPATH/bin/golangci-lint"

atuin init fish | source
starship init fish | source




