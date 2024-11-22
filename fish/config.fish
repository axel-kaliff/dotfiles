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

function vim -d 'vi alias for nvim'
    nvim $argv
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



# bind \cs '__ethp_commandline_toggle_sudo.fish'
bind \cs '__ethp_commandline_toggle_sudo'


export PATH="$PATH:/opt/nvim-linux64/bin"
export PATH="$HOME/tools/node-v14.15.4-linux-x64/bin:$PATH"

# GO
export PATH="$PATH:/usr/local/go/bin"

export GOPATH="$USER/home/go"
alias golint="$GOPATH/bin/golangci-lint"

atuin init fish | source
starship init fish | source
