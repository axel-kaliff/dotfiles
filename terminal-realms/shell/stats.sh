#!/bin/bash
# stats.sh: prints Uptime=, CPU=, Memory=, Battery= lines for the realm screens.
# Uses macchina when it is installed, otherwise reads the system directly (macOS or Linux).
UP=""; CPU=""; MEM=""; BAT=""
if command -v macchina >/dev/null 2>&1; then
    while IFS='=' read -r k v; do
        case "$k" in Uptime) UP="$v";; CPU) CPU="$v";; Memory) MEM="$v";; esac
    done < <(macchina 2>/dev/null | awk '{
        gsub(/\033\[[0-9]+;1H/, "\n"); gsub(/\033\[[0-9;]*[A-Za-z]/, "")
        n = split($0, L, "\n")
        for (i = 1; i <= n; i++) {
            line = L[i]
            if (index(line, "›") == 0) continue
            split("Uptime CPU Memory", K, " ")
            for (j = 1; j <= 3; j++) if (index(line, K[j] " ") > 0) {
                v = line; sub(/.*›[ ]*/, "", v); sub(/[ ]*│.*/, "", v); print K[j] "=" v
            }
        }
    }')
fi
fmt_up() { local s=$1; printf '%dd %dh %dm' $((s / 86400)) $((s % 86400 / 3600)) $((s % 3600 / 60)); }
if [ "$(uname)" = Darwin ]; then
    if [ -z "$UP" ]; then
        boot=$(sysctl -n kern.boottime 2>/dev/null | sed -E 's/.*sec = ([0-9]+).*/\1/')
        [ -n "$boot" ] && UP=$(fmt_up $(( $(date +%s) - boot )))
    fi
    [ -z "$CPU" ] && CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    if [ -z "$MEM" ]; then
        total=$(sysctl -n hw.memsize 2>/dev/null); page=$(sysctl -n hw.pagesize 2>/dev/null)
        used=$(vm_stat 2>/dev/null | awk -v p="$page" '/Pages active|Pages wired down|Pages occupied by compressor/ { gsub(/\./, "", $NF); s += $NF } END { print s * p }')
        [ -n "$total" ] && [ -n "$used" ] && MEM=$(awk -v u="$used" -v t="$total" 'BEGIN { printf "%.1f GB / %.1f GB", u / 1073741824, t / 1073741824 }')
    fi
    BAT=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
else
    [ -z "$UP" ] && [ -r /proc/uptime ] && UP=$(fmt_up "$(cut -d. -f1 /proc/uptime)")
    [ -z "$CPU" ] && CPU=$(awk -F': ' '/model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null)
    [ -z "$MEM" ] && MEM=$(awk '/MemTotal/ { t = $2 } /MemAvailable/ { a = $2 } END { if (t) printf "%.1f GB / %.1f GB", (t - a) / 1048576, t / 1048576 }' /proc/meminfo 2>/dev/null)
    for b in /sys/class/power_supply/BAT*/capacity; do [ -r "$b" ] && BAT=$(cat "$b") && break; done
fi
echo "Uptime=${UP:-n/a}"; echo "CPU=${CPU:-n/a}"; echo "Memory=${MEM:-n/a}"; echo "Battery=${BAT}"
