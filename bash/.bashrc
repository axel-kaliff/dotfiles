# ~/.bashrc — fallback shell only; fish is the daily driver (see fish/config.fish).
# Kept deliberately small: this used to be the stock Debian bashrc on an EL10
# box, carrying a dead nvm block (mise manages node now) and a duplicated PATH.

# Non-interactive shells (including `bash -lc` from justfile recipes) stop here.
case $- in
    *i*) ;;
      *) return;;
esac

# ─── History ─────────────────────────────────────────────────────────────────
HISTCONTROL=ignoreboth      # no duplicates, no leading-space commands
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

# ─── Pager / prompt ──────────────────────────────────────────────────────────
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\u@\h:\w\$ '
fi

case "$TERM" in
    xterm*|rxvt*|*-256color) PS1="\[\e]0;\u@\h: \w\a\]$PS1" ;;
esac

# ─── Colour + aliases ────────────────────────────────────────────────────────
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b ~/.dircolors 2>/dev/null || dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# ─── Completion ──────────────────────────────────────────────────────────────
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ─── Environment ─────────────────────────────────────────────────────────────
# Homebrew before /usr/bin, matching fish: EL10 ships older builds of tools we
# install from brew.
for __brew in /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew" /opt/homebrew; do
    if [ -x "$__brew/bin/brew" ]; then
        eval "$("$__brew/bin/brew" shellenv bash)"
        break
    fi
done
unset __brew

export PATH="$HOME/.local/bin:$PATH"
