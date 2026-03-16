set fish_greeting

# ─── Aliases / Wrappers ──────────────────────────────────────────────────────

function g
    lazygit
end

function ld
    lazydocker
end

function cat
    bat $argv
end

function ls
    eza --icons $argv
end

function ll
    eza -la --icons --git $argv
end

function lt
    eza --tree --icons --level=2 $argv
end

function vi -d 'nvim'
    nvim $argv
end

function v -d 'nvim'
    nvim $argv
end

function vim -d 'nvim'
    nvim $argv
end

function diff
    delta $argv
end

function ps
    procs $argv
end

function du
    dust $argv
end

function dig
    doggo $argv
end

function top
    btm $argv
end

function curl
    xh $argv
end

function sed
    sd $argv
end

function find
    fd $argv
end

# ─── Smart Functions ─────────────────────────────────────────────────────────

# Yazi file manager (cd on exit)
function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# Quick project stats
function stats
    echo "── Lines of Code ──"
    tokei
    echo ""
    echo "── Disk Usage ──"
    dust -d 1
end

# Quick HTTP requests with pretty output
function api -d 'Quick API call with jq'
    xh $argv | jq '.'
end

# Interactive JSON explorer
function jqi -d 'Interactive jq on file or stdin'
    if test (count $argv) -gt 0
        jnv $argv
    else
        set tmp (mktemp -t "jqi.XXXXXX.json")
        command cat > $tmp
        jnv $tmp
        rm -f $tmp
    end
end

# Run command and re-run on file changes
function watch -d 'Watch files and re-run command'
    watchexec $argv
end

# Benchmark commands
function bench -d 'Benchmark a command'
    hyperfine $argv
end

# Render markdown in terminal
function md -d 'Render markdown'
    glow $argv
end

# Encrypt/decrypt files with age
function encrypt -d 'Encrypt file with age'
    age -p -o "$argv[1].age" $argv[1]
    echo "Encrypted to $argv[1].age"
end

function decrypt -d 'Decrypt age file'
    age -d -o (string replace '.age' '' $argv[1]) $argv[1]
end

# Quick ollama chat
function ai -d 'Chat with local LLM'
    if test (count $argv) -gt 0
        ollama run llama3 $argv
    else
        ollama run llama3
    end
end

# aider - AI pair programming
function pair -d 'Start aider AI pair programmer'
    aider $argv
end

# Quick container inspection
function dive-last -d 'Dive into most recent container image'
    set img (podman images --format '{{.Repository}}:{{.Tag}}' | head -1)
    dive $img
end

# Distrobox shortcuts
function box -d 'Enter or create distrobox'
    if test (count $argv) -eq 0
        distrobox list
    else
        distrobox enter $argv[1] 2>/dev/null; or distrobox create -i $argv[1] && distrobox enter $argv[1]
    end
end

# mise - activate for current shell
function use -d 'Set tool version via mise'
    mise use $argv
end

# Quick backup with restic
function backup -d 'Backup directory with restic'
    restic backup $argv
end

# Safe rm via trash
function rm -d 'Move to trash instead of deleting'
    trash $argv
end

# ─── Devcontainer Functions ──────────────────────────────────────────────────

function dn
    if test (count $argv) -lt 1
        echo "Usage: dn <project_name>"
        return 1
    end
    set project $argv[1]
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

function dr
    devcontainer up --mount "type=bind,source=$HOME/.config/nvim,target=/home/devuser/.config/nvim" --workspace-folder . --remove-existing-container
end

# ─── Dotfile Management ──────────────────────────────────────────────────────

function udot
    echo "Committing all changes, pulling from remote, and pushing to remote..."
    cd ~/dotfiles/
    git add .
    git commit -m "Update dotfiles"
    git pull
    git push
    echo "Git repository updated."
    just stow-dotfiles
    echo "Dotfiles synced."
end

function uva
    source .venv/bin/activate
end

# ─── Keybindings ─────────────────────────────────────────────────────────────

bind \cs '__ethp_commandline_toggle_sudo'

# ─── Environment ─────────────────────────────────────────────────────────────

export EDITOR=nvim
export VISUAL=nvim
export XDG_CONFIG_HOME="$HOME/.config/"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin/"

# ─── Shell Integrations ──────────────────────────────────────────────────────

zoxide init fish | source
direnv hook fish | source
fzf --fish | source
atuin init fish | source
mise activate fish | source
starship init fish | source
