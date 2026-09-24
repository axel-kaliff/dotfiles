#!/bin/sh
# name: Solar wallpaper
# icon: weather-clear
# description: Toggle the day/night wallpaper that follows the sun
# keywords: solar wallpaper day night style
t="$HOME/.local/state/pneuma/toggles/solar-wallpaper"
if [ -e "$t" ]; then rm -f "$t"; notify-send -a pneuma "Solar wallpaper off"; exit 0; fi
mkdir -p "$(dirname "$t")" && touch "$t"
exec python3 "$HOME/dotfiles/scripts/solar/solar_wallpaper.py"
