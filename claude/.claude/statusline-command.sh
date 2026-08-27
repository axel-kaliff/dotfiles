#!/usr/bin/env bash
# Claude Code status line script
# Shows: user@host cwd [git-branch] | model | context%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Get git branch (skip locks for safety)
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build context string
ctx_str=""
if [ -n "$used_pct" ]; then
    ctx_str=$(printf "%.0f%% ctx" "$used_pct")
fi

# Build branch string
branch_str=""
if [ -n "$git_branch" ]; then
    branch_str="[$git_branch]"
fi

# Compose the line using ANSI colors via printf
# Colors: bold cyan for path, yellow for branch, dim for model, magenta for ctx
printf '\033[36m%s@%s\033[0m:\033[1;34m%s\033[0m' \
    "$(whoami)" "$(hostname -s)" "$short_cwd"

if [ -n "$branch_str" ]; then
    printf ' \033[33m%s\033[0m' "$branch_str"
fi

if [ -n "$model" ] || [ -n "$ctx_str" ]; then
    printf ' \033[2m|'
    [ -n "$model" ] && printf ' %s' "$model"
    [ -n "$ctx_str" ] && printf ' | %s' "$ctx_str"
    printf '\033[0m'
fi

printf '\n'
