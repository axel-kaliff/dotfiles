# Zellij Cheat Sheet

## Global (works everywhere except locked mode)

| Key | Action |
|-----|--------|
| `Ctrl g` | Toggle locked mode |
| `Ctrl h/j/k/l` | Move focus left/down/up/right |
| `Alt h/j/k/l` | Move focus or tab left/down/up/right |
| `Alt n` | New pane |
| `Alt f` | Toggle floating panes |
| `Alt [` / `Alt ]` | Previous/next swap layout |
| `Alt i` / `Alt o` | Move tab left/right |
| `Alt p` | Toggle pane in group |
| `Alt q` | Clear terminal |
| `Alt z` | Lock (autolock) |
| `Alt +` / `Alt -` | Resize increase/decrease |

## Plugins

| Key | Action |
|-----|--------|
| `Ctrl y` | **room** - fuzzy tab switcher |
| `Alt /` | **forgot** - show all keybinds |
| `Alt b` | **harpoon** - pane bookmarks |
| `Alt m` | **monocle** - fuzzy file finder |
| `Alt t` | **multitask** - mini CI runner |

## Pane Mode (`Ctrl p`)

| Key | Action |
|-----|--------|
| `h/j/k/l` | Move focus |
| `n` | New pane |
| `d` | New pane down |
| `r` | New pane right |
| `s` | New stacked pane |
| `f` | Toggle fullscreen |
| `F` | Toggle fullscreen incl. UI bars (zen) |
| `e` | Toggle embed/floating |
| `w` | Toggle floating panes |
| `c` | Rename pane |
| `i` | Toggle pane pinned |
| `z` | Toggle pane frames |
| `p` | Switch focus |
| `;` | Focus last pane |

## Tab Mode (`Ctrl t`)

| Key | Action |
|-----|--------|
| `h/j/k/l` | Navigate tabs |
| `1-9` | Jump to tab N |
| `n` | New tab |
| `r` | Rename tab |
| `x` | Close tab |
| `s` | Toggle sync |
| `b` | Break pane to new tab |
| `[` / `]` | Break pane left/right |
| `Tab` | Toggle last tab |

## Resize Mode (`Ctrl n`)

| Key | Action |
|-----|--------|
| `h/j/k/l` | Increase size in direction |
| `H/J/K/L` | Decrease size in direction |
| `+` / `-` | Increase/decrease overall |

## Move Mode (`Ctrl m`)

| Key | Action |
|-----|--------|
| `h/j/k/l` | Move pane in direction |
| `n` / `Tab` | Move pane forward |
| `p` | Move pane backward |

## Scroll Mode (`Ctrl s`)

| Key | Action |
|-----|--------|
| `j/k` | Scroll down/up |
| `d/u` | Half page down/up |
| `Ctrl f/b` | Page down/up |
| `[` / `]` | Jump to previous/next prompt (OSC 133) |
| `m` | Select command + its output |
| `c` | Copy last command output |
| `e` | Edit scrollback in nvim |
| `s` | Enter search mode |

## Search (from Scroll Mode, press `s`)

| Key | Action |
|-----|--------|
| `n/p` | Next/previous match |
| `c` | Toggle case sensitivity |
| `w` | Toggle wrap |
| `o` | Toggle whole word |

## Session Mode (`Ctrl o`)

| Key | Action |
|-----|--------|
| `d` | Detach (drops back to the plain shell) |
| `w` | Session manager |
| `c` | Configuration |
| `l` | Layout manager |
| `p` | Plugin manager |
| `a` | About |
| `[` | Descend into nested (guest) session |
| `]` | Ascend back to host session |
| `f` | Toggle nested-session fullscreen |

## Harpoon (inside `Alt b` panel)

| Key | Action |
|-----|--------|
| `a` | Add current pane |
| `A` | Add all panes |
| `d` | Remove bookmark |
| `Enter` / `l` | Jump to pane |
| `j/k` | Navigate list |
