# dotfiles

Personal dotfiles for a terminal-first workflow on Fedora (Silverblue). Managed with `just` and synced to `~/.config/` via rsync.

## Setup

```bash
# First-time install (Homebrew, Tailscale, Atuin)
just first-install

# Install CLI tools + sync dotfiles
just install-cli-applications

# Sync dotfiles to ~/.config/ (safe to re-run)
just overwrite-local-dotfiles

# Apply git config (username, email, delta pager)
just setup-git-config
```

## Stack

| Tool | Purpose |
|------|---------|
| **Ghostty** | Terminal emulator (nordfox theme) |
| **Zellij** | Terminal multiplexer |
| **Fish** | Shell |
| **Neovim** | Editor (Kickstart-based config) |
| **Starship** | Shell prompt |
| **Atuin** | Shell history (synced, fuzzy search) |
| **lazygit** | Git TUI |
| **yazi** | Terminal file manager |

---

## Fish Shell

### Aliases / Functions

| Command | Action |
|---------|--------|
| `g` | Open lazygit |
| `y` | Open yazi (cd on exit) |
| `v` / `vi` / `vim` | Open nvim |
| `cat` | bat (syntax-highlighted cat) |
| `ls` | eza (modern ls with icons) |
| `tm <project>` | tmuxinator start |
| `uva` | Activate `.venv/bin/activate` |
| `udot` | Commit + push dotfiles, then sync locally |
| `dn <name>` | Create new devcontainer project |
| `du` | devcontainer up |
| `db` / `df` / `de` | devcontainer exec bash / fish / nvim |
| `dr` | devcontainer up (rebuild) |
| `Ctrl+S` | Toggle sudo prefix on current command |

### Shell Tools

| Shortcut | Tool | Action |
|----------|------|--------|
| `Ctrl+T` | fzf | Fuzzy find files (uses fd) |
| `Alt+C` | fzf | Fuzzy find and cd into directory |
| `Ctrl+R` | Atuin | Fuzzy search shell history |
| `z <dir>` | zoxide | Jump to frecent directory |
| `zi` | zoxide | Interactive directory picker |

### Environment

- `BAT_THEME=Nord` - bat uses Nord color scheme
- `RIPGREP_CONFIG_PATH` - ripgrep auto-loads config (smart-case, hidden files, excludes .git/node_modules/.venv)
- `direnv` - auto-loads `.envrc` files per project

---

## Zellij

Leader-free navigation. Autolock engages when nvim/vim/git/fzf/zoxide/atuin/ssh are running.

### Global (all modes except locked)

| Shortcut | Action |
|----------|--------|
| `Ctrl+H/J/K/L` | Move focus between panes (also works in nvim via zellij-nav) |
| `Alt+H/J/K/L` | Move focus / tab left/down/up/right |
| `Alt+F` | Toggle floating panes |
| `Alt+N` | New pane |
| `Alt+Y` | Open yazi |
| `Alt+E` | Activate venv + open nvim |
| `Alt+Q` | Clear terminal |
| `Alt+[` / `Alt+]` | Previous / next swap layout |
| `Alt++` / `Alt+-` | Resize increase / decrease |
| `Alt+I` / `Alt+O` | Move tab left / right |

### Lock / Unlock

| Shortcut | Action |
|----------|--------|
| `Alt+Z` | Toggle lock (locks when unlocked, unlocks when locked) |
| `Alt+Shift+Z` | Re-enable autolock plugin |
| `Ctrl+G` | Unlock (switch to normal mode) |

### Mode Switches

| Shortcut | Mode | Key actions in mode |
|----------|------|---------------------|
| `Ctrl+P` | Pane | `n` new, `d` split down, `r` split right, `x` close, `f` fullscreen, `w` float, `s` stacked |
| `Ctrl+T` | Tab | `n` new, `r` rename, `x` close, `1-9` go to tab |
| `Ctrl+N` | Resize | `h/j/k/l` increase, `H/J/K/L` decrease |
| `Ctrl+M` | Move | `h/j/k/l` move pane |
| `Ctrl+S` | Scroll | `j/k` scroll, `d/u` half page, `s` search |
| `Ctrl+B` | Tmux | Familiar tmux bindings (`"` hsplit, `%` vsplit, `c` new tab, `z` zoom) |
| `Ctrl+O` | Session | `w` session manager, `d` detach |
| `Esc` / `Enter` | Return to normal mode |

### Layouts

Start zellij with a layout: `zellij --layout dev`

| Layout | Description |
|--------|-------------|
| `dev` | Editor (70%) + terminal + lazygit sidebar |
| `fullstack` | Editor + frontend/backend panes + logs tab |
| `monitor` | 4-pane grid for monitoring |

---

## Neovim

Leader key: `Space`

### Navigation

| Shortcut | Action |
|----------|--------|
| `Ctrl+H/J/K/L` | Move between splits (crosses into zellij panes) |
| `Ctrl+M` / `Ctrl+N` | Next / previous buffer |
| `gb` | Pick buffer by label |
| `Space bd` | Close current buffer |
| `s` | Flash jump (type characters to jump to) |
| `S` | Flash treesitter select |
| `-` | Open oil.nvim (parent directory as editable buffer) |

### File Finding & Search

| Shortcut | Action |
|----------|--------|
| `Space sf` | Search files (fuzzy find) |
| `Space sg` | Search by grep (live grep across project) |
| `Space sw` | Search current word under cursor |
| `Space s.` | Search recent files |
| `Space sh` | Search help tags |
| `Space sk` | Search keymaps |
| `Space sc` | Search commands |
| `Space sd` | Search diagnostics |
| `Space sr` | Resume last search |
| `Space sn` | Search nvim config files |
| `Space /` | Fuzzy search in current buffer |
| `Space s/` | Live grep in open files |
| `Space Space` | Find open buffers |

### LSP

| Shortcut | Action |
|----------|--------|
| `grd` | Go to definition |
| `grr` | Go to references |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `grD` | Go to declaration |
| `grn` | Rename symbol |
| `gra` | Code action |
| `gO` | Document symbols |
| `gW` | Workspace symbols |
| `Space th` | Toggle inlay hints |
| `Space f` | Format buffer |

Active language servers: `lua_ls`, `pyright`, `ruff`, `gopls`, `ts_ls`, `rust_analyzer`

### Git (gitsigns)

| Shortcut | Action |
|----------|--------|
| `]c` / `[c` | Next / previous git change |
| `Space hs` | Stage hunk |
| `Space hr` | Reset hunk |
| `Space hS` | Stage buffer |
| `Space hR` | Reset buffer |
| `Space hp` | Preview hunk |
| `Space hb` | Blame line |
| `Space hd` | Diff against index |
| `Space hD` | Diff against last commit |
| `Space tb` | Toggle blame line |

### Diagnostics (trouble.nvim)

| Shortcut | Action |
|----------|--------|
| `Space xx` | Toggle diagnostics list |
| `Space xX` | Toggle buffer diagnostics |
| `Space xL` | Toggle location list |
| `Space xQ` | Toggle quickfix list |

### Debugging (DAP)

| Shortcut | Action |
|----------|--------|
| `F5` | Start / continue |
| `F1` | Step into |
| `F2` | Step over |
| `F3` | Step out |
| `F7` | Toggle debug UI |
| `Space b` | Toggle breakpoint |
| `Space B` | Conditional breakpoint |

### File Explorer

| Shortcut | Action |
|----------|--------|
| `Space e` | Toggle Neo-tree (floating) |
| `-` | Open oil.nvim (inline file editing) |

### Session Management

| Shortcut | Action |
|----------|--------|
| `Space qs` | Load session for current directory |
| `Space qS` | Select a session to load |
| `Space ql` | Load last session |
| `Space qd` | Stop session auto-save |

### Other

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save file (works in normal and insert mode) |
| `Space cc` | Toggle centerpad (zen mode) |
| `Esc` | Clear search highlights |

### Formatting & Linting

Formatting runs on save via conform.nvim:
- **Lua**: stylua
- **Python**: ruff_format
- **Fish**: fish_indent

Linting runs on save/enter/insert-leave via nvim-lint:
- **Python**: ruff
- **Bash/Fish/Shell**: shellcheck
- **Markdown**: markdownlint
- **Lua**: luacheck

---

## Git

Delta is configured as the pager (side-by-side diffs with line numbers). Run `just setup-git-config` to apply.

```bash
git diff      # side-by-side with delta
git log -p    # patches rendered with delta
lazygit       # or just type 'g' in fish
```

---

## Directory Structure

```
dotfiles/
├── atuin/          # Shell history config
├── fish/           # Fish shell config, plugins, functions
├── ghostty/        # Terminal emulator config
├── lazygit/        # Git TUI config
├── nvim/           # Neovim config (Kickstart-based)
│   ├── init.lua    # Main config (keymaps, LSP, plugins)
│   └── lua/
│       ├── custom/plugins/   # oil, flash, trouble, neo-tree, etc.
│       └── kickstart/plugins/ # gitsigns, lint, debug, autopairs
├── ripgrep/        # ripgrep config (smart-case, hidden files)
├── tmux/           # Tmux config (backup multiplexer)
├── tmuxinator/     # Tmux session templates
├── yazi/           # File manager config
├── zellij/         # Zellij config + layouts
│   ├── config.kdl
│   └── layouts/    # dev, fullstack, monitor
├── Brewfile        # Homebrew packages
├── justfile        # Setup/install recipes
└── starship.toml   # Shell prompt config
```
