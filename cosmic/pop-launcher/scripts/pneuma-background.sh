#!/bin/sh
# name: Background
# icon: preferences-desktop-wallpaper
# description: Pick a wallpaper (turns the solar wallpaper off)
# keywords: wallpaper background style
rm -f "$HOME/.local/state/pneuma/toggles/solar-wallpaper"
exec cosmic-settings wallpaper
