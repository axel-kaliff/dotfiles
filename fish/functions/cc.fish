# Claude Code has no account switcher of its own — `claude auth login/logout`
# hold exactly one account per config root. CLAUDE_CONFIG_DIR relocates that
# whole root (.claude.json, .credentials.json, sessions, caches), so a fresh
# directory is a fresh login and two accounts can run side by side.
#
# ~/.claude stays the default account and the one copy of the hand-written
# config; a profile is a thin dir that symlinks that config back in and keeps
# only its own credentials and state. `claude` is the default account, `cc
# <name>` is any other.
function cc --description 'Run Claude Code under a named account profile'
    set -l root $HOME/.claude-profiles
    set -l shared CLAUDE.md settings.json statusline-command.sh \
        agents commands hooks output-styles plugins projects rules skills themes

    if test (count $argv) -eq 0
        printf '%-10s %-24s %s\n' default (__cc_email $HOME/.claude.json) 'claude'
        for dir in $root/*
            set -l name (path basename $dir)
            printf '%-10s %-24s %s\n' $name (__cc_email $dir/.claude.json) "cc $name"
        end
        return
    end

    if test $argv[1] = default
        echo "cc: 'default' is ~/.claude — run it with plain `claude`" >&2
        return 1
    end

    set -l dir $root/$argv[1]
    mkdir -p $dir; or return 1
    for entry in $shared
        test -e $HOME/.claude/$entry; or continue
        ln -sfn $HOME/.claude/$entry $dir/$entry; or return 1
    end
    CLAUDE_CONFIG_DIR=$dir command claude $argv[2..]
end

function __cc_email --description 'Account e-mail recorded in a Claude config file'
    jq -r '.oauthAccount.emailAddress // "not logged in"' $argv[1] 2>/dev/null
    or echo 'not logged in'
end
