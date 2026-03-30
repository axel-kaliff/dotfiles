# ─── Greeting ────────────────────────────────────────────────────────────────
# Run `set -U fish_greeting` once to persist across sessions, then this line
# can be removed. Kept here for portability across machines via dotfile sync.
set -g fish_greeting

# ─── Abbreviations (expand in-place, history records the real command) ───────

abbr --add g lazygit
abbr --add ld lazydocker
abbr --add cat bat
abbr --add ls 'eza --icons --group-directories-first'
abbr --add ll 'eza -la --icons --git --group-directories-first --time-style=relative --hyperlink'
abbr --add lt 'eza --tree --icons --level=2 --group-directories-first'
abbr --add vi nvim
abbr --add v nvim
abbr --add vim nvim
abbr --add diff delta
abbr --add ps procs
abbr --add du dust
abbr --add dig doggo
abbr --add top btm
abbr --add curl xh
abbr --add sed sd
abbr --add find fd
abbr --add watch watchexec
abbr --add bench hyperfine
abbr --add md glow
abbr --add pair aider
abbr --add up topgrade
abbr --add rm trash
abbr --add use 'mise use'
abbr --add backup 'restic backup'

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
    if test $pipestatus[2] -ne 0; or test -z "$branch"
        return
    end
    # Strip remote prefix if selecting a remote branch
    set branch (string replace -r '^\* ' '' -- $branch)
    set branch (string replace -r '^remotes/origin/' '' -- $branch)
    git checkout $branch
end

# fzf-powered project jumper via zoxide (scored, with tree preview)
function zp -d 'Fuzzy jump to a project directory'
    set -l dir (zoxide query -ls | fzf --height 50% --layout=reverse \
        --preview 'eza --icons --tree --level=2 --color=always {2..}' \
        --preview-window 'right:50%' \
        --with-nth 2.. \
        | awk '{print $2}')
    if test $pipestatus[2] -ne 0; or test -z "$dir"
        return
    end
    cd $dir
end

# fzf-powered process killer
function fkill -d 'Fuzzy find and kill a process'
    set -l pid (procs --no-header | fzf --height 40% --multi | awk '{print $1}')
    if test $pipestatus[2] -ne 0; or test -z "$pid"
        return
    end
    echo "Killing PID(s): $pid"
    echo $pid | xargs kill $argv
end

# tldr with man fallback
function help -d 'Quick help: tldr with man fallback'
    tldr $argv 2>/dev/null; or man $argv
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
    source .venv/bin/activate.fish
end

# ─── Discovery & Search ─────────────────────────────────────────────────────

# Searchable cheatsheet
function cheat -d 'Search cheatsheet or render it'
    if test (count $argv) -gt 0
        rg -i $argv[1] -C 1 ~/dotfiles/CHEATSHEET.md | bat -l md --style=plain
    else
        glow ~/dotfiles/CHEATSHEET.md
    end
end

# Fuzzy search fish abbreviations
function abbrs -d 'Fuzzy search abbreviations'
    abbr --show | fzf --height 60% --border
end

# Find recently changed files
function recent -d 'Files changed within a duration (default: 1day)'
    fd --changed-within (test (count $argv) -gt 0; and echo $argv[1]; or echo "1day")
end

# Find large files
function bloat -d 'Find files larger than size (default: 10MB)'
    fd --size +(test (count $argv) -gt 0; and echo $argv[1]; or echo "10MB") --type f
end

# ─── Event Handlers ─────────────────────────────────────────────────────────

# Desktop notification for commands that take longer than 10 seconds
function __notify_long_command --on-event fish_postexec
    if test $CMD_DURATION -gt 10000
        set -l secs (math $CMD_DURATION / 1000)
        notify-send --app-name=fish "Command finished ($secs""s)" "$argv[1]" 2>/dev/null
    end
end

# ─── Transient Prompt ────────────────────────────────────────────────────────

# Collapse the starship prompt to a simple marker for already-executed lines,
# keeping scrollback clean while the full prompt shows on the current line.
function fish_transient_prompt
    printf '❯ '
end

# ─── Keybindings ─────────────────────────────────────────────────────────────

bind \cs '__ethp_commandline_toggle_sudo'
bind \ee 'nvim; commandline -f repaint'

# ─── Environment ─────────────────────────────────────────────────────────────

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx CDPATH . ~ ~/projects

# Man pages with syntax highlighting (bat)
set -gx MANPAGER "bat -plman"
set -gx MANROFFOPT "-c"

fish_add_path --append ~/.local/bin
fish_add_path --append ~/.linuxbrew/bin

# ─── Tool Configuration (set before shell integrations) ─────────────────────

# fzf: use fd backend, reverse layout, previews, scroll bindings
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --strip-cwd-prefix'
set -gx FZF_DEFAULT_OPTS '--layout=reverse --border=rounded --height=~80% --min-height=20 --info=inline-right --scroll-off=3 --cycle --bind=ctrl-/:toggle-preview --bind=ctrl-u:preview-half-page-up --bind=ctrl-d:preview-half-page-down --bind=ctrl-space:toggle+down'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_CTRL_T_OPTS '--preview "[ -d {} ] && eza --all --icons --tree --level=2 --color=always {} || bat --color=always --style=numbers,changes --line-range=:200 {}" --preview-window=right:55%:hidden --bind=ctrl-/:toggle-preview'
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --strip-cwd-prefix'
set -gx FZF_ALT_C_OPTS '--preview "eza --all --icons --tree --level=2 --color=always {}" --preview-window=right:55%'

# zoxide: tree preview for zi, exclude noise directories
set -gx _ZO_FZF_OPTS '--height=60% --layout=reverse --border=rounded --preview "eza --icons --tree --level=2 --color=always {2..}" --preview-window=right:45%:wrap --bind=ctrl-/:toggle-preview'
set -gx _ZO_EXCLUDE_DIRS "$HOME:$HOME/Downloads:$HOME/.cache:/tmp"

# direnv: dim output instead of noisy env-diff
set -gx DIRENV_LOG_FORMAT (printf '\033[2mdirenv: %%s\033[0m')

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

# ─── Post-Integration Keybinding Overrides ──────────────────────────────────

# fzf: rebind file finder from Ctrl+T (Zellij Tab mode) to Alt+T
bind --erase \ct
bind \et fzf-file-widget
if bind -M insert \ct 2>/dev/null
    bind -M insert --erase \ct
    bind -M insert \et fzf-file-widget
end

functions -c fish_command_not_found __original_command_not_found
function fish_command_not_found
    __original_command_not_found $argv
end
