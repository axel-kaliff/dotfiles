# ~/.bash_profile — login shells, interactive or not. The COSMIC session starts through
# `$SHELL -l`, so this is where the desktop gets Homebrew and ~/.local/bin on its PATH;
# .bashrc returns early for non-interactive shells and cannot do it.
for __brew in /home/linuxbrew/.linuxbrew "$HOME/.linuxbrew" /opt/homebrew; do
    if [ -x "$__brew/bin/brew" ]; then
        eval "$("$__brew/bin/brew" shellenv bash)"
        break
    fi
done
unset __brew
export PATH="$HOME/.local/bin:$PATH"

# shellcheck source=/dev/null
[ -f ~/.bashrc ] && . ~/.bashrc
