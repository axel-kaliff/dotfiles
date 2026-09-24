#!/bin/sh
# name: Update system
# icon: system-software-update
# description: Bluefin, Flatpaks and Homebrew
# keywords: update upgrade ujust
exec cosmic-term -- bash -lc 'ujust update; echo; read -rp "Done. Press Enter to close."'
