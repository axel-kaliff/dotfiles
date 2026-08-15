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
| `gwt [branch]` | Jump to the worktree holding a branch, even mid-rebase (fzf when ambiguous) |
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
| `Alt+H/J/K/L` | Move focus / tab — **also works while locked** |
| `Alt+W` | Session manager — **also works while locked** |
| `Alt+F` | Toggle floating panes |
| `Alt+N` | New pane |
| `Alt+E` | Activate venv + open nvim |
| `Alt+Y` | Open yazi |
| `Alt+Q` | Clear terminal |
| `Alt+[` / `Alt+]` | Cycle layouts |
| `Alt++` / `Alt+-` | Resize panes |
| `Alt+I` / `Alt+O` | Move tab left / right |

### Lock / Unlock

Autolock locks the session whenever the focused pane runs `nvim`, `claude`,
`git`, `fzf`, `zoxide` or `atuin`, so their `Ctrl` chords reach the TUI instead
of Zellij. `Alt+H/J/K/L` and `Alt+W` stay live while locked — use those to get
out of a locked pane rather than unlocking.

| Shortcut | What it does |
|----------|-------------|
| `Alt+Z` | Toggle lock |
| `Alt+Shift+Z` | Re-enable autolock |
| `Ctrl+G` | Unlock (autolock re-locks ~1s later) |

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
| `zj ide <name>` | Claude IDE session on worktree `.worktrees/<name>` (creates branch + worktree if missing) |
| `zj ide` | Same, but fzf-pick an existing worktree |
| `zj ide done <name>` | Kill session + remove worktree + delete branch (refuses dirty/unmerged) |

#### Claude IDE session (`zj ide`)

Claude Code 58% left · Neogit top-right (live, 2s poll) · shell bottom-right.
Pane icons via Claude hooks: 🤖 working · 💬 waiting for input · ✅ done.
The claude and neogit panes autolock zellij so their `Ctrl` keys reach the TUI —
navigate with `Alt+H/J/K/L` and open the session manager with `Alt+W`, both of
which stay live while locked. Rerunning `zj ide <name>` just re-attaches; use it
instead of `zj reset` (reset loses the worktree cwd).

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
| `Shift+H` / `Shift+L` | Previous / next buffer |
| `[b` / `]b` | Previous / next buffer |
| `Space ws` / `Space wh` | Split vertical / horizontal |
| `Space wd` | Close split |
| `Space w=` | Equalize splits |
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

### Neogit (magit-style git)

Entry points: `Space gn` status buffer, `Space gc` commit popup, `Space gp` push popup.
Inside any Neogit buffer, `?` opens the help popup listing every binding — when in doubt, press it.

**The loop:** `Space gn` → move to a file or hunk → `s` to stage → `c c` to commit → write the
message → `Ctrl+C Ctrl+C` to save it → `P p` to push. `q` closes the status buffer.

Everything is positional: `s`, `u`, and `x` act on whatever the cursor is on — a whole section, a
file, a single hunk, or (in visual mode) just the selected lines. Fold with `Tab` to see files,
unfold to see hunks.

#### Status buffer

| Shortcut | What it does |
|----------|-------------|
| `Tab` | Fold / unfold item under cursor |
| `1` / `2` / `3` / `4` | Set fold depth for the whole buffer |
| `s` / `u` | Stage / unstage item under cursor (or visual selection) |
| `S` / `U` | Stage all unstaged / unstage all staged |
| `Ctrl+S` | Stage everything, untracked included |
| `x` | Discard item under cursor (destructive) |
| `K` | Untrack file (keeps it on disk) |
| `Enter` | Open the file under cursor |
| `Shift+Enter` | Peek file without leaving the status buffer |
| `Ctrl+V` / `Ctrl+X` / `Ctrl+T` | Open in vsplit / split / tab |
| `{` / `}` | Previous / next hunk header |
| `Ctrl+P` / `Ctrl+N` | Previous / next section |
| `y` | Show refs (branches, tags, remotes) |
| `Y` | Yank the hash/path under cursor |
| `$` | Git command history + output |
| `Ctrl+R` | Refresh buffer |
| `q` | Close |

#### Popups

Each popup is a menu: press its key from the status buffer, then pick an action inside it.

| Key | Popup | Common actions inside |
|-----|-------|----------------------|
| `?` | Help | Lists everything below |
| `c` | Commit | `c` commit, `a` amend, `e` extend (amend, keep message), `w` reword, `f` fixup, `s` squash |
| `P` | Push | `p` to pushRemote, `u` to upstream, `e` elsewhere, `T` a tag |
| `p` | Pull | `p` from pushRemote, `u` from upstream, `e` elsewhere |
| `f` | Fetch | `p` pushRemote, `u` upstream, `a` all remotes |
| `b` | Branch | `b` checkout branch, `l` local branch, `c` checkout new branch, `n` create (stay put), `m` rename, `D` delete |
| `r` | Rebase | `u` onto upstream, `b` onto base branch, `i` interactively, `w` reword a commit, `d` drop a commit, `f` autosquash |
| `m` | Merge | Merge a branch into the current one |
| `l` | Log | `l` current branch, `b` all branches, `r` reflog |
| `d` | Diff | `d` this, `u` unstaged, `s` staged, `w` worktree, `r` range (opens diffview) |
| `Z` | Stash | `z` stash both, `i` index only, `p` pop, `a` apply, `d` drop |
| `A` | Cherry-pick | Pick commits onto the current branch |
| `v` | Revert | Revert a commit |
| `X` | Reset | `s` soft, `m` mixed, `h` hard, `k` keep, `f` a file, `b` a branch |
| `t` | Tag | Create, delete, or push tags |
| `w` | Worktree | Create, checkout, or delete worktrees |
| `i` | Ignore | Add path under cursor to `.gitignore` |
| `B` | Bisect | Start / good / bad / reset |

Inside a popup, `-<key>` toggles a switch and `=<key>` sets an option before you run the action —
e.g. in the push popup `-f` arms `--force-with-lease`, then `p` pushes with it. In the rebase popup
`-i` arms interactive. Switches stick between sessions unless marked otherwise.

#### Commit editor

| Shortcut | What it does |
|----------|-------------|
| `Ctrl+C Ctrl+C` | Save the message and commit (`:wq` also works) |
| `Ctrl+C Ctrl+K` | Abort the commit |
| `Alt+P` / `Alt+N` | Cycle through previous commit messages |
| `Alt+R` | Reset the message back to its original |
| `q` | Close |

#### Interactive rebase editor

Opened by `r i`. One line per commit — mark each, then submit.

| Shortcut | What it does |
|----------|-------------|
| `p` / `r` / `e` | Pick / reword / edit |
| `s` / `f` | Squash / fixup into the commit above |
| `x` / `b` / `d` | Execute a shell command / break / drop |
| `gj` / `gk` | Move the commit under cursor down / up |
| `Enter` | Open the commit under cursor |
| `Ctrl+C Ctrl+C` | Run the rebase |
| `Ctrl+C Ctrl+K` | Abort |

While a rebase is in progress, `r` in the status buffer offers `r` continue, `s` skip, `e` edit,
`a` abort. Conflicts are easiest to resolve with `Space gd` (diffview).

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
