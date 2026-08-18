#!/bin/sh
# Default shell for zellij: fish if available, zsh as fallback
if command -v fish >/dev/null 2>&1; then
    exec fish "$@"
else
    exec zsh "$@"
fi
