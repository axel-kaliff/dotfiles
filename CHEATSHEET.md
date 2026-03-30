# Cheat Sheet

Quick reference for the full terminal workflow. Render in terminal with `md CHEATSHEET.md`.

---

## Shell (Fish)

### Everyday Commands

| Command | What it does |
|---------|-------------|
| `g` | lazygit |
| `ld` | lazydocker |
| `y` | yazi file manager (cd on exit) |
| `up` | Update everything (topgrade) |
| `help <cmd>` | tldr cheatsheet, falls back to man |
| `cheat [term]` | Search cheatsheet (or render with glow) |
| `abbrs` | Fuzzy search all abbreviations |
| `stats` | Lines of code + disk usage |
| `ai` | Chat with local LLM |
| `pair` | Start aider AI pair programmer |
| `md file.md` | Render markdown in terminal |

### Navigation

| Command | What it does |
|---------|-------------|
| `z <dir>` | Jump to frecent directory (zoxide) |
| `zi` | Interactive directory picker (with tree preview) |
| `zp` | Fuzzy project jumper (scored, with tree preview) |
| `Alt+T` | Fuzzy find files with preview (fzf + fd + bat) |
| `Alt+C` | Fuzzy cd into directory with preview (fzf + fd + eza) |
| `Ctrl+R` | Search shell history (atuin) |
| `Ctrl+/` | Toggle preview in any fzf picker |

### Git

| Command | What it does |
|---------|-------------|
| `g` | lazygit |
| `gbr` | Fuzzy branch switcher (fzf, sorted by recent) |
| `udot` | Interactive dotfile commit + push + stow |

### Development

| Command | What it does |
|---------|-------------|
| `tdd py -- pytest` | Watch files, re-run tests on change |
| `tdd go -- go test ./...` | Same for Go |
| `tdd js,ts -- npm test` | Same for JS/TS |
| `watch -e rs cargo build` | Generic file watcher |
| `bench 'cmd1' 'cmd2'` | Benchmark commands (hyperfine) |
| `api GET url` | HTTP request with pretty JSON |
| `jqi file.json` | Interactive JSON explorer |
| `use node@20` | Set tool version (mise) |

### Processes

| Command | What it does |
|---------|-------------|
| `ps` | Color-coded process list (procs) |
| `top` | System monitor TUI (btm) |
| `fkill` | Fuzzy find and kill a process |

### Files & Search

| Command | What it does |
|---------|-------------|
| `ls` | eza with icons, dirs first |
| `ll` | Long list with git status, relative times, clickable |
| `lt` | Tree view (2 levels) |
| `cat file` | Syntax-highlighted view (bat, with git change markers) |
| `find pattern` | Fast file search (fd) |
| `rg pattern` | Fast content search (ripgrep) |
| `recent [dur]` | Files changed within duration (default: 1day) |
| `bloat [size]` | Find files larger than size (default: 10MB) |
| `rm file` | Move to trash (safe delete) |
| `man cmd` | Syntax-highlighted man pages (bat) |

### Containers

| Command | What it does |
|---------|-------------|
| `ld` | lazydocker TUI |
| `dive-last` | Inspect most recent image layers |
| `box` | Interactive distrobox picker |
| `box ubuntu` | Enter/create Ubuntu distrobox |

### Devcontainers

| Command | What it does |
|---------|-------------|
| `dn` | New devcontainer project (gum prompt) |
| `dn myapp` | New devcontainer project named "myapp" |
| `dc` | Start devcontainer (mounts nvim config) |
| `db` / `df` / `de` | Exec bash / fish / nvim in container |
| `dr` | Rebuild devcontainer from scratch |

### Secrets & Encryption

| Command | What it does |
|---------|-------------|
| `encrypt file` | Encrypt with age (password prompt) |
| `decrypt file.age` | Decrypt age file |
| `env-encrypt` | Encrypt `.env` with sops+age |
| `env-encrypt secrets.yaml` | Encrypt a specific file |
| `env-decrypt file.enc` | Decrypt sops-encrypted file |

### Recording & Docs

| Command | What it does |
|---------|-------------|
| `rec` | Create + edit a vhs tape, record terminal GIF |
| `rec demo.tape` | Run an existing tape file |
| `md README.md` | Render markdown in terminal |
| `slides deck.md` | Terminal slideshow from markdown |

### Dotfile Management

| Command | What it does |
|---------|-------------|
| `udot` | Commit + push + stow (interactive with gum) |
| `reload` | Reload fish config |
| `reload --zellij` | Reload fish + reset zellij session |
| `uva` | Activate Python venv |

### Keybindings

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+S` | Toggle sudo on current command |
| `Alt+T` | Fuzzy file finder with preview (fzf) |
| `Alt+C` | Fuzzy cd with tree preview (fzf) |
| `Ctrl+/` | Toggle preview in any fzf/zoxide picker |

### Atuin (shell history TUI at Ctrl+R)

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+R` | Open atuin / cycle filter mode (global/host/session/dir/workspace) |
| `Ctrl+S` | Cycle search mode (prefix/fulltext/fuzzy) |
| `Ctrl+O` | Inspect selected command (exit code, duration, dir) |
| `Tab` | Paste command into prompt for editing (don't execute) |
| `Enter` | Execute selected command immediately |
| `Ctrl+D` | Delete history entry (in inspector) |

---

## Zellij

### Navigation (all modes except locked)

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+H/J/K/L` | Move between panes (crosses into nvim) |
| `Alt+H/J/K/L` | Move focus / tab |
| `Alt+F` | Toggle floating panes |
| `Alt+N` | New pane |
| `Alt+E` | Activate venv + open nvim |
| `Alt+Y` | Open yazi |
| `Alt+Q` | Clear terminal |
| `Alt+[` / `Alt+]` | Cycle layouts |
| `Alt++` / `Alt+-` | Resize panes |
| `Alt+I` / `Alt+O` | Move tab left / right |

### Lock / Unlock

| Shortcut | What it does |
|----------|-------------|
| `Alt+Z` | Toggle lock |
| `Alt+Shift+Z` | Re-enable autolock |
| `Ctrl+G` | Unlock |

### Mode Switches

| Shortcut | Mode | Actions |
|----------|------|---------|
| `Ctrl+P` | Pane | `n` new `d` down `r` right `x` close `f` full `w` float `s` stack |
| `Ctrl+T` | Tab | `n` new `r` rename `x` close `1-9` goto |
| `Ctrl+N` | Resize | `hjkl` grow `HJKL` shrink |
| `Ctrl+M` | Move | `hjkl` move pane |
| `Ctrl+S` | Scroll | `jk` scroll `du` half-page `s` search |
| `Ctrl+B` | Tmux | `"` hsplit `%` vsplit `c` tab `z` zoom |
| `Ctrl+O` | Session | `w` manager `d` detach |

### Sessions & Layouts

| Command | What it does |
|---------|-------------|
| `zj` | Attach/create session (named after cwd) |
| `zj myproject` | Attach/create named session |
| `zj ls` | List sessions |
| `zj kill <name>` | Kill session |
| `zl` | List available layouts |
| `zl dev` | Start session with dev layout |
| `zl fullstack` | Start session with fullstack layout |
| `zl monitor` | Start session with monitor layout |
| `zj reset <name>` | Kill + restart with original layout |

---

## Yazi

### Navigation

| Shortcut | What it does |
|----------|-------------|
| `h/l` | Parent / enter directory (l = smart-enter: opens files too) |
| `j/k` | Move down / up |
| `H/L` | Directory history back / forward |
| `Enter` | Open file |
| `!` | Open fish shell here |
| `z` | fzf jump to directory |
| `Z` | Zoxide jump (uses your frecency database) |
| `Ctrl+U/D` | Half page up / down |

### Search & Filter

| Shortcut | What it does |
|----------|-------------|
| `s` | **Search filenames** recursively (fd) |
| `S` | **Search file contents** recursively (ripgrep) |
| `f` | Smart filter (live filter as you type) |
| `/` | Incremental find in current directory |
| `n/N` | Next / previous match |

### Selection & Operations

| Shortcut | What it does |
|----------|-------------|
| `Space` | Toggle selection on hovered file |
| `v` | Visual mode (select range) |
| `Ctrl+A` | Select all |
| `y` / `x` | Yank (copy) / yank (cut) |
| `p` / `P` | Paste / paste with overwrite |
| `d` / `D` | Trash / permanent delete |
| `a` | Create file (trailing `/` = directory) |
| `r` | Rename (with multiple selected = bulk rename in editor) |

### Display & Metadata

| Shortcut | What it does |
|----------|-------------|
| `.` | Toggle hidden files |
| `,m` `,s` `,e` `,n` | Sort by modified / size / extension / natural |
| `ms` `mp` `mm` `mo` | Linemode: show size / permissions / modified / owner |
| `cc` `cd` `cf` `cn` | Copy: full path / directory / filename / name without ext |
| `K/J` | Scroll preview up / down |
| `Tab` | Spot view (detailed file metadata) |
| `t` | New tab, `[`/`]` switch tabs |
| `w` | Task manager (background operations) |

### Bookmarks

| Shortcut | Destination |
|----------|-------------|
| `g d` | `~/dotfiles` |
| `g p` | `~/Projects` |
| `g c` | `~/.config` |
| `g D` | `~/Downloads` |
| `g o` | `~/Documents` |

---

## Neovim

Leader: `Space`

### Navigation

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+H/J/K/L` | Move between splits (crosses into zellij) |
| `Ctrl+M` / `Ctrl+N` | Next / previous buffer |
| `gb` | Pick buffer |
| `Space bd` | Close buffer |
| `s` | Flash jump |
| `S` | Flash treesitter select |
| `-` | Oil file explorer |
| `Space e` | Oil floating window |

### Search (fzf-lua)

| Shortcut | What it does |
|----------|-------------|
| `Space sf` | Find files |
| `Space sg` | Live grep |
| `Space sw` | Grep word under cursor |
| `Space s.` | Recent files |
| `Space sR` | Search and replace (grug-far) |
| `Space /` | Search in current buffer |
| `Space Space` | Open buffers |

### LSP

| Shortcut | What it does |
|----------|-------------|
| `grd` | Go to definition |
| `grr` | Go to references |
| `gri` | Go to implementation |
| `grn` | Rename symbol |
| `gra` | Code action |
| `gO` | Document symbols |
| `Space f` | Format buffer |
| `Space th` | Toggle inlay hints |

### Git

| Shortcut | What it does |
|----------|-------------|
| `]c` / `[c` | Next / prev change |
| `Space hs` | Stage hunk |
| `Space hr` | Reset hunk |
| `Space hp` | Preview hunk |
| `Space hb` | Blame line |
| `Space gg` | Lazygit |
| `Space gn` | Neogit |
| `Space gd` | Diffview |
| `Space gh` | File history |

### Diagnostics & Debug

| Shortcut | What it does |
|----------|-------------|
| `Space xx` | Toggle diagnostics |
| `Space xQ` | Toggle quickfix |
| `F5` | Debug: start/continue |
| `F1/F2/F3` | Step into/over/out |
| `F7` | Toggle debug UI |
| `Space b` | Toggle breakpoint |

### Text Objects

| Shortcut | What it does |
|----------|-------------|
| `af/if` | Around/inside function |
| `ac/ic` | Around/inside class |
| `aa/ia` | Around/inside argument |
| `]m/[m` | Next/prev function |
| `Space a/A` | Swap argument forward/back |

### Other

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+S` | Save |
| `gcc` | Toggle comment |
| `gc` (visual) | Comment selection |
| `Space cc` | Zen mode |
| `Space tt` | Floating terminal |
| `Space qs` | Load session |
| `Space ql` | Load last session |

### Oil (file explorer)

| Shortcut | What it does |
|----------|-------------|
| `Enter` | Open |
| `-` | Parent directory |
| `g.` | Toggle hidden files |
| `gd` | Toggle details |
| `g\` | Toggle trash view |
| `Space y` | Yank filepath |

Create/rename/delete by editing the buffer text and saving with `:w`.
