# dotfiles

Personal dotfiles for a terminal-first workflow on Fedora (Silverblue). Managed with `just` and symlinked to `~/.config/` via GNU Stow.

## Setup

```bash
# Full bootstrap (Homebrew, Stow, dotfiles, git, fish, fonts, Atuin, Tailscale)
just bootstrap

# Symlink dotfiles to ~/.config/ via stow (idempotent, safe to re-run)
just stow-dotfiles

# Remove all symlinks
just unstow-dotfiles

# Check what's installed
just doctor

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

### Abbreviations

These expand inline so you see the real command before running it, and history records the expanded form.

| Abbreviation | Expands to |
|--------------|------------|
| `g` | `lazygit` |
| `v` / `vi` / `vim` | `nvim` |
| `cat` | `bat` |
| `ls` | `eza` |

### Functions

| Command | Action |
|---------|--------|
| `y` | Open yazi (cd on exit) |
| `uva` | Activate `.venv/bin/activate` |
| `udot` | Commit + push dotfiles, then `just stow-dotfiles` |
| `dn <name>` | Create new devcontainer project |
| `dc` | devcontainer up (with nvim config mounted) |
| `db` / `df` / `de` | devcontainer exec bash / fish / nvim |
| `dr` | devcontainer up (rebuild) |
| `r2d2` | SSH into r2d2 with tmux (auto-syncs nvim config) |
| `rvim [host]` | Sync nvim config to remote host and open nvim |
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

Leader-free navigation. Autolock engages when nvim/vim/git/fzf/zoxide/atuin are running.

### Sessions

The `zj` function manages sessions:

| Command | Action |
|---------|--------|
| `zj` | Attach/create session named after current directory |
| `zj <name>` | Attach/create session with given name |
| `zj ls` | List sessions |
| `zj kill <name>` | Kill a session |
| `zj layout <name> <layout>` | Attach with a specific layout (remembers layout for reset) |
| `zj reset <name>` | Kill session and restart with its original layout |

### Global (all modes except locked)

| Shortcut | Action |
|----------|--------|
| `Ctrl+H/J/K/L` | Move focus between panes (also works in nvim via zellij-nav) |
| `Alt+H/J/K/L` | Move focus / tab left/down/up/right |
| `Alt+F` | Toggle floating panes |
| `Alt+N` | New pane |
| `Alt+Y` | Open yazi |
| `Alt+E` | Open nvim (activates .venv first if present) |
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
| `sics` | Remote development on r2d2 (2 remote shells + remote neovim editor) |

#### sics layout (remote development)

The `sics` layout connects to the `r2d2` remote for development:

- **remote-1 / remote-2**: SSH into r2d2 and attach to shared tmux sessions
- **editor**: Rsyncs neovim config to r2d2, then opens nvim over SSH

```bash
# Start the sics session
zj layout sics sics

# Reset it back to the original layout (kills and restarts)
zj reset sics
```

#### Automatic nvim config sync

The `ssh` function automatically rsyncs your neovim config to r2d2 before every connection. This covers manual SSH, the `r2d2` function, and the sics layout scripts -- your remote nvim config always matches local.

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

### File Finding & Search (fzf-lua)

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
| `Space sR` | Search and replace (grug-far, project-wide) |
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

### Git

#### Gitsigns (inline hunks)

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

#### Neogit & Diffview (full git workflow)

| Shortcut | Action |
|----------|--------|
| `Space gn` | Neogit (magit-style interactive git UI) |
| `Space gc` | Neogit commit |
| `Space gp` | Neogit push |
| `Space gg` | Lazygit (via snacks.nvim) |
| `Space gl` | Lazygit log |
| `Space gd` | Diffview (review all changed files) |
| `Space gh` | File history (current file) |
| `Space gH` | File history (entire repo) |

### Commenting

Built-in (Neovim 0.11+, no plugin needed):

| Shortcut | Action |
|----------|--------|
| `gcc` | Toggle comment on current line |
| `gc` (visual) | Toggle comment on selection |

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

### File Explorer (Oil)

| Shortcut | Action |
|----------|--------|
| `Space e` | Open Oil in floating window |
| `-` | Open Oil (parent directory as editable buffer) |

#### Oil Keymaps (inside Oil buffer)

| Shortcut | Action |
|----------|--------|
| `Enter` | Open file or directory |
| `-` | Go to parent directory |
| `g.` | Toggle hidden files |
| `gd` | Toggle detail view (permissions, size, mtime) |
| `gs` | Change sort order |
| `<C-p>` | Preview file in split |
| `<C-s>` | Open in vertical split |
| `<C-t>` | Open in new tab |
| `<C-c>` | Close Oil |
| `g\` | Toggle trash view |
| `gx` | Open with external program |
| `Space y` | Yank filepath to clipboard |

#### Oil File Operations

Oil treats directories as editable buffers. To perform file operations, edit the buffer text then save:

| Operation | How |
|-----------|-----|
| **Create file** | Type a new filename on a blank line, `:w` |
| **Create directory** | Type a new name ending with `/`, `:w` |
| **Rename** | Edit the filename text directly, `:w` |
| **Delete** | Delete the line (`dd`), `:w` |
| **Move** | Cut a line (`dd`), navigate to target dir, paste (`p`), `:w` |
| **Copy** | Yank a line (`yy`), navigate to target dir, paste (`p`), `:w` |

Deleted files go to trash (use `g\` to view/restore). Simple edits (renames, creates) skip the confirmation dialog.

#### Oil SSH (Remote Editing)

Oil can browse and edit remote filesystems over SSH using your local nvim config:

```vim
:Oil oil-ssh://hostname/~/path/
:Oil oil-ssh://user@hostname//absolute/path/
```

All file operations (create, rename, delete, move) work over SSH.

### Treesitter Textobjects

| Shortcut | Action |
|----------|--------|
| `af` / `if` | Select around/inside function |
| `ac` / `ic` | Select around/inside class |
| `aa` / `ia` | Select around/inside argument |
| `]m` / `[m` | Next / previous function start |
| `]M` / `[M` | Next / previous function end |
| `]]` / `[[` | Next / previous class start |
| `Space a` | Swap with next argument |
| `Space A` | Swap with previous argument |
| `;` / `,` | Repeat last textobject move forward / backward |

### Focus & Zen

| Shortcut | Action |
|----------|--------|
| `Space cc` | Toggle Zen Mode (centered 90-col writing, via snacks.nvim) |

### UI (snacks.nvim & noice.nvim)

| Shortcut | Action |
|----------|--------|
| `Space tt` | Toggle floating terminal |
| `Space un` | Notification history |

snacks.nvim also provides: dashboard, indent guides, smooth scrolling, bigfile handling, word highlighting under cursor, and lazygit integration.

noice.nvim replaces the command line, messages, and popupmenu with modern floating windows.

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

## Dotfile Management

Dotfiles are symlinked using GNU Stow. The entire `dotfiles/` directory is stowed as a single package into `~/.config/`, with a `.stow-local-ignore` excluding non-config files (Brewfile, justfile, etc.).

```bash
# Sync everything
just stow-dotfiles

# One-step commit + push + restow
udot
```

The `bash` package is stowed separately to `~` (for `~/.bashrc`).

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
├── bash/           # Bash config (~/.bashrc, stowed to ~)
├── fish/           # Fish shell config, plugins, functions
├── ghostty/        # Terminal emulator config
├── lazygit/        # Git TUI config
├── nvim/           # Neovim config (Kickstart-based)
│   ├── init.lua    # Main config (keymaps, LSP, plugins)
│   └── lua/
│       ├── custom/plugins/   # fzf-lua, snacks, noice, neogit, diffview, oil, flash, trouble, grug-far
│       └── kickstart/plugins/ # gitsigns, lint, debug, autopairs, remote
├── ripgrep/        # ripgrep config (smart-case, hidden files)
├── starship.toml   # Shell prompt config
├── yazi/           # File manager config
├── zellij/         # Zellij config + layouts
│   ├── config.kdl
│   └── layouts/    # dev, fullstack, monitor, sics
├── Brewfile        # Homebrew packages
└── justfile        # Setup/install recipes
```
