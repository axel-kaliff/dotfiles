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

# ─── Workflow Functions ──────────────────────────────────────────────────────

# TDD: watch files and re-run tests on change
function tdd -d 'Watch files and re-run tests on change'
    if test (count $argv) -gt 0
        watchexec -e $argv
    else
        echo "Usage: tdd <extensions> -- <test command>"
        echo "  tdd py,rs -- just test"
        echo "  tdd go -- go test ./..."
        echo "  tdd js,ts -- npm test"
    end
end

# fzf-powered git branch switching
function gbr -d 'Fuzzy switch git branch'
    set -l branch (git branch --all --sort=-committerdate | string trim | fzf --height 40% --preview 'git log --oneline -10 {1}')
    if test -n "$branch"
        # Strip remote prefix if selecting a remote branch
        set branch (string replace -r '^\* ' '' -- $branch)
        set branch (string replace -r '^remotes/origin/' '' -- $branch)
        git checkout $branch
    end
end

# fzf-powered project jumper via zoxide
function zp -d 'Fuzzy jump to a project directory'
    set -l dir (zoxide query -l | fzf --height 40% --preview 'eza --icons --tree --level=1 {1}')
    if test -n "$dir"
        cd $dir
    end
end

# fzf-powered process killer
function fkill -d 'Fuzzy find and kill a process'
    set -l pid (procs --no-header | fzf --height 40% --multi | awk '{print $1}')
    if test -n "$pid"
        echo "Killing PID(s): $pid"
        echo $pid | xargs kill $argv
    end
end

# tldr with man fallback
function help -d 'Quick help: tldr with man fallback'
    tldr $argv 2>/dev/null; or man $argv
end

# Update everything with topgrade
function up -d 'Update all packages and tools'
    topgrade
end

# Zellij layout launcher
function zl -d 'Start zellij with a layout'
    if test (count $argv) -eq 0
        echo "Available layouts:"
        command ls ~/.config/zellij/layouts/ | string replace '.kdl' ''
        return
    end
    zj layout $argv[1] $argv[1]
end

# sops-encrypted env files
function env-encrypt -d 'Encrypt .env file with sops+age'
    if test (count $argv) -eq 0
        set argv .env
    end
    if not test -f $argv[1]
        echo "File not found: $argv[1]"
        return 1
    end
    sops --encrypt --age (age-keygen -y ~/.config/sops/age/keys.txt 2>/dev/null) $argv[1] >$argv[1].enc
    echo "Encrypted to $argv[1].enc"
end

function env-decrypt -d 'Decrypt sops-encrypted env file'
    if test (count $argv) -eq 0
        echo "Usage: env-decrypt <file.enc>"
        return 1
    end
    set -l outfile (string replace -r '\.enc$' '' $argv[1])
    sops --decrypt $argv[1] >$outfile
    echo "Decrypted to $outfile"
end

# Record terminal session as GIF
function rec -d 'Record terminal session with vhs'
    if test (count $argv) -eq 0
        # Generate a starter tape file
        set -l tapefile (mktemp -t "recording.XXXXXX.tape")
        echo "# VHS tape file - edit then run: vhs $tapefile" >$tapefile
        echo 'Output recording.gif' >>$tapefile
        echo 'Set FontSize 14' >>$tapefile
        echo 'Set Width 1200' >>$tapefile
        echo 'Set Height 600' >>$tapefile
        echo 'Type "echo hello"' >>$tapefile
        echo 'Enter' >>$tapefile
        echo 'Sleep 1s' >>$tapefile
        echo "Created starter tape: $tapefile"
        echo "Edit it, then run: vhs $tapefile"
        $EDITOR $tapefile
    else
        vhs $argv
    end
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
        set -l boxes (distrobox list --no-color 2>/dev/null | tail -n +2 | awk '{print $3}')
        if test -z "$boxes"
            echo "No distroboxes found. Create one with: box <image>"
            return 0
        end
        set -l choice (echo $boxes | tr ' ' '\n' | gum choose --header "Select distrobox")
        if test -n "$choice"
            distrobox enter $choice
        end
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
        set -l project (gum input --placeholder "Project name")
        if test -z "$project"
            echo "Aborted."
            return 1
        end
        set argv $project
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
    cd ~/dotfiles/
    git add .
    echo ""
    git status --short
    echo ""
    if not gum confirm "Commit and push these dotfile changes?"
        echo "Aborted."
        return 0
    end
    set -l msg (gum input --placeholder "Commit message (empty = 'Update dotfiles')")
    if test -z "$msg"
        set msg "Update dotfiles"
    end
    git commit -m "$msg"
    git pull --rebase
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
bind \ee 'nvim; commandline -f repaint'

# ─── Environment ─────────────────────────────────────────────────────────────

export EDITOR=nvim
export VISUAL=nvim
export XDG_CONFIG_HOME="$HOME/.config/"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin/"

# ─── Zellij Auto-Start ───────────────────────────────────────────────────────

if status is-interactive; and test "$TERM" = "xterm-ghostty"; and not set -q ZELLIJ
    eval (zellij setup --generate-auto-start fish | string collect)
end

# ─── Shell Integrations ──────────────────────────────────────────────────────

zoxide init fish | source
direnv hook fish | source
fzf --fish | source
atuin init fish | source
mise activate fish | source
starship init fish | source

functions -c fish_command_not_found __original_command_not_found
function fish_command_not_found
    __original_command_not_found $argv
end
