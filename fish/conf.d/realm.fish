status is-interactive; or return

test -n "$REALM_HOME"; or set -g REALM_HOME "$HOME/.config/terminal-realms"
set -gx REALM_HOME "$REALM_HOME"
set -gx REALM bonfire
set -g REALM_DIR "$REALM_HOME/realms/bonfire"

function wizseb
    switch "$argv[1]"
        case ''
            echo "This window: $REALM"
            echo 'Commands: wizseb open | join | close | pin | unpin | flare'
        case open
            if test -n "$ZELLIJ"
                echo 'Already inside Zellij. Leave it first (Ctrl+q).'
                return 1
            end
            if not command -q zellij
                echo 'Zellij is not installed (brew install zellij).'
                return 1
            end
            for i in (seq 30)
                zellij delete-session realm-bonfire --force >/dev/null 2>&1
                zellij list-sessions --no-formatting 2>/dev/null | string match -rq '^realm-bonfire( |$)'; or break
                sleep 0.2
            end
            zellij --new-session-with-layout "$REALM_DIR/layout.kdl" --session realm-bonfire
        case join
            zellij attach realm-bonfire
        case close
            zellij delete-session realm-bonfire --force >/dev/null 2>&1
            return 0
        case pin
            functions -q _realm_pin; and _realm_pin
        case unpin
            functions -q _realm_unpin; and _realm_unpin
        case flare
            functions -q _realm_flare; and _realm_flare
        case '*'
            echo "Unknown command '$argv[1]'. Type: wizseb"
            return 1
    end
end

test -z "$REALM_QUIET"; or return
test -x "$REALM_DIR/screen.sh"; or return
set -g REALM_SCREEN "$REALM_DIR/screen.sh"
bash "$REALM_SCREEN"

set -g _realm_dir "$HOME/.cache/terminal-realms"
mkdir -p "$_realm_dir" 2>/dev/null
bash "$REALM_SCREEN" height 2>/dev/null | read -g _realm_h _realm_w
test -n "$_realm_h"; or set -g _realm_h 19
test -n "$_realm_w"; or set -g _realm_w 62
test -n "$REALM_SECONDS"; or set -g REALM_SECONDS 25
test -n "$REALM_FLARE"; or set -g REALM_FLARE 1
test -n "$REALM_BELL"; or set -g REALM_BELL 1
test -n "$REALM_FLARE_AFTER"; or set -g REALM_FLARE_AFTER 10
test -n "$REALM_FLARE_SKIP"; or set -g REALM_FLARE_SKIP 'nvim vim vi less man more htop top btop ssh tmux zellij fzf lazygit watch tail'
test -n "$REALM_DIED"; or set -g REALM_DIED 1
test -n "$REALM_DIED_SKIP"; or set -g REALM_DIED_SKIP 'grep egrep fgrep rg diff cmp test [ [[ which command type git fzf'
if test -z "$REALM_QUOTE"
    set -gx REALM_QUOTE (REALM_SHELL=$fish_pid bash "$REALM_SCREEN" quote 2>/dev/null)
end
set -gx REALM_QUOTE "$REALM_QUOTE"
set -g _realm_cmd ''
set -g _realm_rc 0
set -g _realm_duration ''
set -g _realm_pinned 1
test -z "$REALM_PIN"; or set -g _realm_pinned "$REALM_PIN"

function _realm_ok
    test "$_realm_pinned" = 1; and test "$LINES" -ge (math "$_realm_h + 6"); and test "$COLUMNS" -ge "$_realm_w"
end

function _realm_stop
    set -l f "$_realm_dir/anim-$fish_pid.pid"
    test -r "$f"; or return 0
    set -l p (string trim < "$f")
    set -l i 0
    if test -n "$p"
        kill "$p" 2>/dev/null
        while kill -0 "$p" 2>/dev/null; and test $i -lt 30
            set i (math "$i + 1")
            sleep 0.01
        end
    end
    command rm -f "$f"
end

function _realm_start
    _realm_ok; or return 0
    _realm_stop
    test "$REALM_SECONDS" = 0; and return 0
    set -l fl 0
    set -l dd 0
    test "$argv[1]" = flare; and test "$REALM_FLARE" != 0; and set fl 1
    test "$argv[1]" = died; and test "$REALM_DIED" != 0; and set dd 1
    REALM_FLARE=$fl REALM_DIED=$dd REALM_SHELL=$fish_pid bash "$REALM_SCREEN" anim "$REALM_SECONDS" </dev/null >/dev/null 2>&1 &
    set -l p $last_pid
    echo $p > "$_realm_dir/anim-$fish_pid.pid"
    # Fish owns background jobs until disowned.
    disown $p 2>/dev/null
end

set -g _realm_failed 0
function _realm_check_fail
    set -l rc $argv[1]
    set -g _realm_failed 0
    if test "$REALM_DIED" = 0; or test -z "$_realm_cmd"; or test $rc -eq 0; or test $rc -eq 130
        return 0
    end
    if test $rc -eq 1; and contains -- "$_realm_cmd" (string split ' ' -- "$REALM_DIED_SKIP")
        return 0
    end
    set -g _realm_failed 1
end

set -g _realm_long 0
function _realm_timer
    set -g _realm_long 0
    test -n "$_realm_duration"; or return 0
    set -l elapsed "$_realm_duration"
    set -g _realm_duration ''
    test "$elapsed" -ge (math "$REALM_FLARE_AFTER * 1000"); or return 0
    contains -- "$_realm_cmd" (string split ' ' -- "$REALM_FLARE_SKIP"); and return 0
    set -g _realm_long 1
end

function _realm_postexec --on-event fish_postexec
    set -l rc $status
    set -g _realm_rc $rc
    set -g _realm_duration "$CMD_DURATION"
end

function _realm_precmd --on-event fish_prompt
    _realm_timer
    _realm_check_fail $_realm_rc
    set -g _realm_rc 0
    set -g _realm_cmd ''
    _realm_ok; or return 0
    printf '\0337\033[%d;%dr\0338' (math "$_realm_h + 1") "$LINES"
    if test $_realm_failed -ne 0
        _realm_start died
        test $_realm_long -ne 0; and test "$REALM_BELL" != 0; and printf '\a'
    else if test $_realm_long -ne 0
        _realm_start flare
        test "$REALM_BELL" != 0; and test "$REALM_FLARE" != 0; and printf '\a'
    else
        _realm_start
    end
end

function _realm_preexec --on-event fish_preexec
    _realm_stop
    set -l c (string match -r '^\s*\S+' -- "$argv[1]" | string trim)
    set -g _realm_cmd (path basename -- "$c")
end

function _realm_clear
    printf '\033[%d;1H\033[J' (math "$_realm_h + 1")
end

function clear
    if _realm_ok
        _realm_clear
    else
        command clear
    end
end

function _realm_resize --on-signal WINCH
    _realm_stop
    if _realm_ok
        bash "$REALM_SCREEN" resize </dev/null >/dev/null 2>&1
        _realm_start
    else
        printf '\033[r'
    end
end

function _realm_unpin
    _realm_stop
    set -g _realm_pinned 0
    printf '\033[r'
    echo "Unpinned: scrollback works normally. Type 'wizseb pin' to pin the screen again."
end

function _realm_pin
    set -g _realm_pinned 1
    REALM_PIN=1 bash "$REALM_SCREEN"
    _realm_start
end

function _realm_flare
    _realm_start flare
    test "$REALM_BELL" != 0; and printf '\a'
    return 0
end

function _realm_exit --on-event fish_exit
    _realm_stop
    printf '\033[r'
end

function _realm_widget
    clear
    commandline -f repaint
end

bind -M default ctrl-l _realm_widget
bind -M insert ctrl-l _realm_widget
