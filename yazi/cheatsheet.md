# Yazi Cheatsheet

Press `q` (or `Ctrl-c` in this pager) to close. Full searchable list: `~` or `F1` inside yazi.

## Custom bindings (this config)

| Key | Action |
|-----|--------|
| `l` | Smart enter: enter dir **or** open file |
| `f` | Smart filter (submits on unique match) |
| `!` | Open fish shell here |
| `g d` | Go to ~/dotfiles |
| `g p` | Go to ~/Projects |
| `g c` | Go to ~/.config |
| `g D` | Go to ~/Downloads |
| `g o` | Go to ~/Documents |
| `P P` | Restore tab session (auto-saved continuously) |

## Navigation

| Key | Action |
|-----|--------|
| `h` / `l` | Parent dir / enter (smart-enter) |
| `j` / `k` | Next / previous file |
| `g g` / `G` | Top / bottom |
| `Ctrl-d` / `Ctrl-u` | Half page down / up |
| `H` / `L` | History back / forward |
| `g h` | Go home |
| `g Space` | Jump interactively (cd prompt) |
| `g f` | Follow hovered symlink |
| `g t` | Go to trash bin |
| `z` | Jump via fzf (files in cwd) |
| `Z` | fzf over directory history (zoxide, all sessions) |
| `J` / `K` | Scroll the **preview** down / up |
| `Tab` | Spot (file info popup) |

## Selection

| Key | Action |
|-----|--------|
| `Space` | Toggle selection, move down |
| `v` / `V` | Visual mode (select / unset) |
| `Ctrl-a` | Select all |
| `Ctrl-r` | Invert selection |
| `Esc` | Clear selection / exit visual / cancel |

## File operations

| Key | Action |
|-----|--------|
| `o` / `Enter` | Open |
| `O` / `Shift-Enter` | Open interactively (choose opener) |
| `y` / `x` | Yank copy / cut |
| `p` / `P` | Paste / paste force-overwrite |
| `Y` or `X` | Cancel yank |
| `-` / `_` | Symlink absolute / relative |
| `d` / `D` | Trash / delete permanently |
| `a` | Create (trailing `/` = directory) |
| `A` | Bulk create |
| `r` | Rename (cursor before extension) |
| `;` / `:` | Shell command / blocking shell command |
| `.` | Toggle hidden files |
| `w` | Task manager (`x` cancels a task) |

## Copy path

| Key | Action |
|-----|--------|
| `c c` | Copy file path |
| `c d` | Copy directory path |
| `c f` | Copy filename |
| `c n` | Copy filename without extension |

## Find & search

| Key | Action |
|-----|--------|
| `f` | Smart filter (jump/open as you type) |
| `F` | Persistent filter — act on the filtered set (Esc clears) |
| `/` | Find next in list |
| `n` / `N` | Next / previous match |
| `s` | Search recursively by name (fd) |
| `S` | Search by content (ripgrep) |
| `Ctrl-s` | Cancel ongoing search |

## Sort & display

| Key | Action |
|-----|--------|
| `, m` / `, M` | Sort by modified time (/ reverse) |
| `, s` / `, S` | Sort by size (/ reverse) |
| `, n` / `, N` | Sort naturally (/ reverse) |
| `, a` / `, e` / `, b` | Sort alphabetical / extension / btime |
| `m s` `m p` `m m` `m o` `m n` | Linemode: size, permissions, mtime, owner, none |

## Tabs

| Key | Action |
|-----|--------|
| `t t` | New tab in CWD |
| `t r` | Rename tab |
| `1`–`9` | Switch to tab N |
| `[` / `]` | Previous / next tab |
| `{` / `}` | Swap tab left / right |
| `Ctrl-c` | Close tab (quit if last) |

## Quit

| Key | Action |
|-----|--------|
| `q` | Quit (writes cwd-file → shell cd) |
| `Q` | Quit without cwd-file |
| `Ctrl-z` | Suspend |
