#!/usr/bin/env bash
# Claude Code status line script

# ANSI color codes
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

FG_BLUE='\033[34m'
FG_CYAN='\033[36m'
FG_GREEN='\033[32m'
FG_YELLOW='\033[33m'
FG_RED='\033[31m'
FG_MAGENTA='\033[35m'
FG_WHITE='\033[37m'

# Separators
SEP_LEFT=''   # Powerline left solid arrow
SEP_THIN=''  # Powerline left thin arrow

# Read JSON input
input=$(cat)

# Extract fields from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "unknown"')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Shorten the working directory: replace $HOME with ~
home_dir="$HOME"
display_cwd="${cwd/#$home_dir/\~}"

# Get git branch (skip optional locks to avoid conflicts)
git_branch=""
if git_out=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null); then
  if [ -n "$git_out" ]; then
    git_branch="$git_out"
  fi
fi

# Build context usage indicator
context_segment=""
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "$used_int" -ge 80 ]; then
    ctx_color="$FG_RED"
    ctx_icon=""
  elif [ "$used_int" -ge 50 ]; then
    ctx_color="$FG_YELLOW"
    ctx_icon=""
  else
    ctx_color="$FG_GREEN"
    ctx_icon=""
  fi
  context_segment="${ctx_color}${ctx_icon} ${used_int}%${RESET}"
fi

# Build the status line
printf '%b' "${DIM}${FG_BLUE}${BOLD} ${display_cwd}${RESET}"

if [ -n "$git_branch" ]; then
  printf '%b' "  ${DIM}${FG_MAGENTA}${BOLD} ${git_branch}${RESET}"
fi

if [ -n "$context_segment" ]; then
  printf '%b' "  ${DIM}${context_segment}"
fi

printf '%b' "  ${DIM}${FG_CYAN}${model}${RESET}"
printf '%b' "\n"
