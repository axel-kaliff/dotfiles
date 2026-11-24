#!/bin/bash
# screen.sh: the bonfire theme's terminal screen. Pixel-art bonfire (emberscreen) over the Wizards Bonfire
# box, pinned to the top of the terminal. Same commands as render.sh, used by screen.zsh:
#   screen.sh            draw the pinned screen       screen.sh anim [N]   burn for N seconds
#   screen.sh resize     repaint after a resize        screen.sh height     print "<rows> <min cols>"
#   screen.sh quote      print this shell's quote
#   REALM_FLARE=1 / REALM_DIED=1 (set by screen.zsh after long or failed commands)
ESC=$'\033'; RST="${ESC}[0m"
D="$(cd "$(dirname "$0")" && pwd)"; TR="$(cd "$D/../.." && pwd)"
MODE_ARG=${1:-init}; SECS_ARG=${2:-}

# ---------- edit these ----------
# Set these in ~/.config/terminal-realms/settings.zsh:
#   REALM_BONFIRE_TITLE="Wizards Bonfire"
#   REALM_BONFIRE_INFO="Wizard=Yes;Boss=Artorias;Weapon=Balder Side Sword"   (up to 3 label=value pairs)
TITLE_TEXT="${REALM_BONFIRE_TITLE:-Wizards Bonfire}"
CUSTOM_LABELS=(); CUSTOM_VALUES=()
IFS=';' read -r -a _pairs <<< "${REALM_BONFIRE_INFO:-Class=Pyromancer;Boss=Artorias;Weapon=Zweihander}"
for _p in "${_pairs[@]:0:3}"; do CUSTOM_LABELS+=("${_p%%=*}"); CUSTOM_VALUES+=("${_p#*=}"); done
C_BORDER="${ESC}[38;5;202m"; C_TITLE="${ESC}[1;38;5;208m"; C_KEY="${ESC}[38;5;220m"
C_SEP="${ESC}[38;5;160m"; C_VAL="${ESC}[38;5;214m"; C_QUOTE="${ESC}[3;38;5;173m"
QUOTES=(
    "Praise the sun!" "Don't you dare go hollow." "Fear not, the dark, my friend." "Amazing chest ahead."
    "Be wary of ambush." "Try jumping." "Time for jolly cooperation!" "Rest at the bonfire, then roll again."
    "Git gud, wizard." "Only one ember away from a fresh start." "Light the fire. Keep the flame."
    "Hold fast. The next bonfire is close."
)
# --------------------------------

SH=12                              # scene rows
INNER=58; BOXW=$((INNER + 2))
NL=$(( ${#CUSTOM_LABELS[@]} + 3 )) # custom rows + Uptime, CPU, Memory
H=$(( SH + 1 + 1 + (NL + 1) / 2 + 3 ))   # scene + gap + box top + stat rows + bars, quote, bottom
if [ "$MODE_ARG" = height ]; then echo "$H $((BOXW + 2))"; exit 0; fi

SHELLPID=${REALM_SHELL:-$PPID}
QUOTE="${REALM_QUOTE:-}"
[ -z "$QUOTE" ] && QUOTE="${QUOTES[$(( SHELLPID % ${#QUOTES[@]} ))]}"
QUOTE="${QUOTE:0:50}"
if [ "$MODE_ARG" = quote ]; then printf '%s\n' "$QUOTE"; exit 0; fi
CACHE="$HOME/.cache/terminal-realms"; mkdir -p "$CACHE" 2>/dev/null
PIDFILE="$CACHE/anim-$SHELLPID.pid"
[ "$MODE_ARG" = anim ] && echo $$ > "$PIDFILE"

# ---- live stats (macchina if installed, otherwise read from the system) ----
UP="n/a"; CPU="n/a"; MEM="n/a"; BATPCT=-1
while IFS='=' read -r k v; do
    case "$k" in Uptime) UP="$v";; CPU) CPU="$v";; Memory) MEM="$v";; Battery) [ -n "$v" ] && BATPCT="$v";; esac
done < <(bash "$TR/shell/stats.sh" 2>/dev/null)
LABELS=("${CUSTOM_LABELS[@]}" "Uptime" "CPU" "Memory")
VALUES=("${CUSTOM_VALUES[@]}" "$UP" "$CPU" "$MEM")
NL=${#LABELS[@]}

MEMPCT=-1
set -- $MEM
if [ -n "$1" ] && [ -n "$4" ]; then MEMPCT=$(awk -v u="$1" -v t="$4" 'BEGIN { if (t > 0) printf "%d", 100 - (u / t) * 100 }'); fi
[ "$MEMPCT" -gt 100 ] 2>/dev/null && MEMPCT=100
BARW=14
C_HP="${ESC}[38;5;196m"; C_ST="${ESC}[38;5;34m"; C_EMPTY="${ESC}[38;5;238m"
bar() {
    local pct=$1 color=$2 f e fs es
    if [ "$pct" -lt 0 ] 2>/dev/null; then printf '%s%-*s' "$C_EMPTY" $((BARW + 5)) "n/a"; return; fi
    f=$(( pct * BARW / 100 )); e=$(( BARW - f ))
    printf -v fs '%*s' "$f" ''; printf -v es '%*s' "$e" ''
    printf '%s%s%s%s %s%3d%%' "$color" "${fs// /█}" "$C_EMPTY" "${es// /░}" "$C_VAL" "$pct"
}
dashes() { local s; printf -v s '%*s' "$1" ''; printf '%s' "${s// /─}"; }
spaces() { printf '%*s' "$1" ''; }
cell() { printf '%s%-8s%s› %s%-17.17s%s' "$C_KEY" "$1" "$C_SEP" "$C_VAL" "$2" "$RST"; }
barcell() { printf '%s%7s %s%s' "$C_KEY" "$1" "$(bar "$2" "$3")" "$RST"; }

read -r ROWS COLS < <(stty size </dev/tty 2>/dev/null)
if [ -z "$COLS" ]; then COLS=$(tput cols 2>/dev/null || echo 80); ROWS=$(tput lines 2>/dev/null || echo 0); fi
MB=$(( (COLS - BOXW) / 2 )); [ "$MB" -lt 0 ] && MB=0
MH=$(( (COLS - 61) / 2 )); [ "$MH" -lt 0 ] && MH=0

box_rows() {
    local r half=$(( (NL + 1) / 2 )) left right pad ql lp rp
    pad="$(spaces $MB)"
    printf '\n'
    printf '%s%s╭%s%s%s%s╮%s\n' "$pad" "$C_BORDER" "$C_TITLE" "$TITLE_TEXT" "$C_BORDER" "$(dashes $((INNER - ${#TITLE_TEXT})))" "$RST"
    for ((r = 0; r < half; r++)); do
        left="$(cell "${LABELS[$r]}" "${VALUES[$r]}")"
        if [ $((r + half)) -lt "$NL" ]; then right="$(cell "${LABELS[$((r + half))]}" "${VALUES[$((r + half))]}")"; else right="$(spaces 27)"; fi
        printf '%s%s│%s %s  %s %s│%s\n' "$pad" "$C_BORDER" "$RST" "$left" "$right" "$C_BORDER" "$RST"
    done
    printf '%s%s│%s %s  %s %s│%s\n' "$pad" "$C_BORDER" "$RST" "$(barcell "HP" "$BATPCT" "$C_HP")" "$(barcell "Stamina" "$MEMPCT" "$C_ST")" "$C_BORDER" "$RST"
    ql=$(( ${#QUOTE} + 4 )); lp=$(( (INNER - ql) / 2 )); rp=$(( INNER - ql - lp ))
    printf '%s%s│%s%s%s†%s %s %s%s†%s%s%s│%s\n' "$pad" "$C_BORDER" "$RST" "$(spaces $lp)" "$C_SEP" "$C_QUOTE" "$QUOTE" "$RST" "$C_SEP" "$RST" "$(spaces $rp)" "$C_BORDER" "$RST"
    printf '%s%s╰%s╯%s\n' "$pad" "$C_BORDER" "$(dashes $INNER)" "$RST"
}
BOXTXT=$(box_rows; printf x); BOXTXT=${BOXTXT%x}
export BOXTXT EMBER_MH=$MH REALM_SHELL=$SHELLPID EMBER_FLARE=${REALM_FLARE:-0} EMBER_DIED=${REALM_DIED:-0}

CAN_PIN=0
if [ "$ROWS" -ge $((H + 6)) ] && [ "$COLS" -ge $((BOXW + 2)) ] && command -v perl >/dev/null 2>&1; then CAN_PIN=1; fi
[ "${REALM_PIN:-1}" = 0 ] && CAN_PIN=0
SECS=${SECS_ARG:-25}; [ "$SECS" = inf ] && SECS=1000000000

case "$MODE_ARG" in
anim)
    if [ "$CAN_PIN" = 1 ] && [ "$SECS" != 0 ]; then
        EMBER_PIN=anim EMBER_SECS=$SECS PIDFILE="$PIDFILE" exec perl "$D/emberscreen" >/dev/tty 2>/dev/null </dev/null
    fi
    rm -f "$PIDFILE" ;;
paint|resize)
    if [ "$CAN_PIN" = 1 ]; then
        { [ "$MODE_ARG" = resize ] && printf '\0337\033[%d;%dr\0338' $((H + 1)) "$ROWS"
          EMBER_PIN=paint EMBER_FLARE=0 EMBER_DIED=0 perl "$D/emberscreen"; } >/dev/tty 2>/dev/null
    else
        printf '\033[r' >/dev/tty 2>/dev/null
    fi ;;
*)
    if [ "$CAN_PIN" = 1 ]; then
        printf '\033[2J\033[H'
        EMBER_PIN=paint EMBER_FLARE=0 EMBER_DIED=0 perl "$D/emberscreen"
        printf '\033[%d;%dr\033[%d;1H' $((H + 1)) "$ROWS" $((H + 1))
    else
        EMBER_PIN=paint EMBER_MH=0 BOXTXT="" perl "$D/emberscreen" | sed 's/\x1b7//; s/\x1b8//'
        printf '\n%s' "$BOXTXT"
    fi ;;
esac
