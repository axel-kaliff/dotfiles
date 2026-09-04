# dotfiles

Personal dotfiles for a terminal-first workflow on **pneuma** — a custom Fedora
Atomic image (`ghcr.io/axel-kaliff/pneuma`) running Omarchy on Hyprland, with
Ghostty as the terminal. Managed with `just` and symlinked to `~/.config/` via
GNU Stow. A second machine, the **r2d2** homeserver, syncs the same repo and
takes the `*.r2d2.*` config variants.

> This repo is **public** and a systemd timer commits and pushes it every 15
> minutes. Secrets must never land in the working tree — see
> [Secret handling](#secret-handling).

## Setup

On a fresh pneuma install everything is pre-configured. For manual setup, or on another machine:

```bash
# Full bootstrap (Homebrew, Stow, dotfiles, git, fish, fonts, Atuin, Tailscale)
just bootstrap

# Or use the ujust first-time setup on pneuma
ujust setup

# Symlink dotfiles to ~/.config/ via stow (idempotent, safe to re-run)
just stow-dotfiles

# Remove all symlinks
just unstow-dotfiles

# Check what's installed
just doctor

# Apply git config (username, email, delta pager)
just setup-git-config

# Update everything (brew, flatpak, system)
ujust update-all
```

## Stack

### Core Tools

| Tool | Purpose |
|------|---------|
| **Ghostty** | Terminal emulator |
| **Hyprland / Omarchy** | Wayland compositor and desktop shell — Omarchy defaults with personal overrides in `hypr/*.lua`, bar layout in `omarchy/shell.json` |
| **Zellij** | Terminal multiplexer |
| **Fish** | Shell (with zoxide, mise, fzf, atuin integrations) |
| **Neovim** | Editor (Kickstart-based config) |
| **Starship** | Shell prompt |
| **Atuin** | Shell history (synced, fuzzy search, directory/workspace filtering) |
| **lazygit** | Git TUI |
| **lazydocker** | Container TUI (same keybindings as lazygit) |
| **yazi** | Terminal file manager |

### Modern CLI Replacements

| Tool | Replaces | Usage |
|------|----------|-------|
| **bat** | `cat` | `cat file.txt` (aliased, with git change markers + man pager) |
| **eza** | `ls` | `ls` (aliased in fish) |
| **fd** | `find` | `fd pattern` — simple, fast file search |
| **ripgrep** | `grep` | `rg pattern` — fast recursive search |
| **sd** | `sed` | `sd 'from' 'to' file` — intuitive find-and-replace |
| **procs** | `ps` | `procs` — color-coded, searchable process list |
| **dust** | `du` | `dust` — disk usage with visual tree |
| **bottom** | `htop` | `btm` — system monitor TUI |
| **xh** | `curl` | `xh GET api.example.com` — friendly HTTP client |
| **doggo** | `dig` | `doggo example.com` — modern DNS client (supports DoH/DoT) |
| **delta** | `diff` | Git pager (auto-configured, side-by-side diffs) |
| **zoxide** | `cd` | `z dir` — jump to frecent directories |
| **trash-cli** | `rm` | `trash file` — safe delete to trash |

### Developer Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| **mise** | Polyglot version manager + per-directory env | `mise use node@20`; `[env]` in `mise.toml` replaces direnv/`.envrc` |
| **devcontainer** | Dev containers | `dn project` — create devcontainer project |
| **just** | Command runner | `just recipe` — project-specific task runner |
| **watchexec** | File watcher | `watchexec -e rs cargo test` — re-run on file changes |
| **hyperfine** | Benchmarking | `hyperfine 'cmd1' 'cmd2'` — compare command speed |
| **tokei** | Code stats | `tokei` — lines of code by language |
| **gum** | Script UX | Build interactive shell scripts with prompts/spinners |
| **vhs** | Terminal GIFs | `vhs record.tape` — record terminal sessions |

### AI/LLM

Claude Code is the agent in use; it is installed via `mise` (`~/.config/mise/config.toml`),
not Homebrew. `zj ide` pairs it with a git worktree — see [Zellij](#zellij).
ollama and aider were removed in Aug 2026: neither was installed, and aider
upstream has been dormant since Aug 2025.

### Container & Cloud

| Tool | Purpose | Usage |
|------|---------|-------|
| **podman** | Container runtime | `podman run ...` — rootless containers |
| **podman-compose** | Compose files | `podman-compose up` — docker-compose compatible |
| **lazydocker** | Container TUI | `lazydocker` — manage containers/images/volumes |
| **dive** | Image inspector | `dive image:tag` — explore container image layers |
| **skopeo** | Image management | `skopeo inspect docker://image` — inspect/copy images |
| **distrobox** | Container distros | `distrobox create -i ubuntu` — run any distro |

### Network & Security

| Tool | Purpose | Usage |
|------|---------|-------|
| **tailscale** | VPN mesh | Pre-configured with systray, `tailscale up` to connect |
| **nmap** | Network scanner | `nmap -sV host` — port/service discovery |
| **bandwhich** | Bandwidth monitor | `sudo bandwhich` — per-process bandwidth usage |
| **trippy** | Traceroute TUI | `trip host` — visual traceroute |
| **age** | File encryption | `age -r recipient file` — modern GPG alternative |
| **sops** | Secret management | `sops file.yaml` — encrypted secrets in git |

### File Sync & Backup

| Tool | Purpose | Usage |
|------|---------|-------|
| **restic** | Encrypted backup | `restic backup ~/Documents` — deduplicated, encrypted |
| **rclone** | Cloud sync | `rclone sync local/ remote:bucket` — any cloud provider |

### Terminal Productivity

| Tool | Purpose | Usage |
|------|---------|-------|
| **glow** | Markdown viewer | `glow README.md` — render markdown in terminal |
| **presenterm** | Presentations | `presenterm deck.md` — terminal slides from markdown |
| **fzf** | Fuzzy finder | `Alt+T` files (with preview), `Alt+C` cd (with tree preview), `Ctrl+R` history |
| **jq** | JSON processor | `curl api | jq '.data'` — query/transform JSON |
| **jnv** | JSON explorer | `jnv file.json` — interactive jq filter builder |
| **tealdeer** | Quick help | `tldr tar` — community-maintained command examples |
| **topgrade** | Update all | `topgrade` — update brew, flatpak, system in one go |

### Neovim LSP/Lint/Format Dependencies

These are auto-used by neovim's config — no manual invocation needed:

| Tool | Purpose |
|------|---------|
| **rust-analyzer** | Rust LSP |
| **pyright** | Python LSP |
| **tree-sitter** | Syntax parsing |
| **stylua** | Lua formatter |
| **luacheck** | Lua linter |
| **markdownlint-cli** | Markdown linter |
| **ruff** | Python linter/formatter |
| **shellcheck** | Shell script linter |

---

## Desktop

Hyprland 0.56 (Lua config) with the Omarchy 4 shell, in the glass design
language of the `glass` branch. Everything here sits on top of Omarchy's
defaults, in `hypr/*.lua` and `omarchy/`.

### Keybindings added on top of Omarchy

| Shortcut | Action |
|----------|--------|
| `Super+H/J/K/L` (+`Shift`) | Focus / swap windows, vim-style |
| `Alt+Tab` / `Alt+Shift+Tab` | Window switcher: most recent first, live thumbnails; release `Alt` to land, `Esc` cancels |
| `Super+R` then `H/J/K/L` | Resize mode (held keys repeat); `Esc` or any other key leaves, the OSD shows the mode |
| `Super+U` | Focus the window asking for attention, or the last one |
| `Super+Shift+M` / four fingers down | Music scratchpad: Spotify in its own special workspace, launched on first use |
| `Super+Shift+Space` | Next keyboard layout (us / se) |
| `Super+Shift+F` | yazi, with its last session restored |
| `Super+Alt+K` | Zellij cheat sheet |

### Backgrounds

`~/Pictures/Backgrounds` is a wallpaper library. The launcher's Style ▸
Background row (`scripts/backgrounds/pick`, wired in
`omarchy/extensions/omarchy-menu.jsonc`) lists it next to the current theme's
own images, with labels and type-to-filter. `scripts/backgrounds/import-bluefin`
fills it with the Bluefin wallpapers, converted from JPEG XL, which the picker
cannot read. Picking an image turns the solar wallpaper off; the Style ▸ Solar
Wallpaper row turns it back on. The picker thumbnails through `vipsthumbnail`,
which the pneuma image lacks, so `scripts/backgrounds/shim/` stands in with
ImageMagick until `vips-tools` lands in the image.

### Solar wallpaper

`scripts/solar/` computes sunrise and sunset for Stockholm and, every ten
minutes (`solar-wallpaper.timer`) and after every theme change (theme-set
hook), shows the day or night half of the Bluefin wallpaper pair for the
current month, converted once from JPEG XL into `~/.local/share/pneuma/solar/`.
The night light follows the same clock. Enable with
`omarchy toggle solar-wallpaper on` or the launcher's Style ▸ Solar Wallpaper
row. `SOLAR_LATITUDE`/`SOLAR_LONGITUDE`, `SOLAR_NIGHTLIGHT=0` and
`SOLAR_DAY_THEME`/`SOLAR_NIGHT_THEME` in the service unit move it or make it
switch themes. Tests:
`cd scripts/solar && uv run --with pytest --with hypothesis pytest`.

### Compositor behaviour

- **Battery-aware blur** (`hypr/power.lua`): on battery the frost drops from three passes at 12px to two at 8px, and returns on the charger. A compositor timer polls sysfs; no daemon.
- **Screen-share hygiene** (`hypr/privacy.lua`): notification toasts and the clipboard history never appear in a shared screen, and a running share holds off the idle lock. Screen-capture permissions are enforced: grim, hyprpicker, gpu-screen-recorder, quickshell and the portal are allowed, anything else prompts.
- **Scratchpads** (`hypr/scratchpads.lua`): named special workspaces that launch their app through `on_created_empty` and vanish when it closes.
- Glass group tabs, pointer hiding after three idle seconds, floating-window snapping and back-and-forth workspace switching live in `hypr/looknfeel.lua` and `hypr/bindings.lua`.

### Shell plugins

| Plugin | What it adds |
|--------|--------------|
| `pneuma.switcher` | The Alt-Tab overlay (`omarchy-shell pneuma.switcher next / prev / commit / cancel / state`) |
| `pneuma.pomodoro` | Focus timer; a ticking focus phase silences notifications (`focusDnd`) |
| `pneuma.safeeyes` | Eye-break overlays |
| `pneuma.clipboard` | Clipboard history entry point |
| `akaliff.workspaces` | Workspace pills with the apps' icons |
| `akaliff.bar`, `akaliff.notifications`, `akaliff.osd`, `akaliff.media` | Clones of the stock plugins wearing the glass material |

---

## Fish Shell

### Transparent Replacements

These replace standard commands — just use them as normal, the better version runs automatically:

| You type | Runs | Improvement |
|----------|------|-------------|
| `cat file` | `bat` | Syntax highlighting, line numbers, git change markers |
| `man cmd` | `bat` (MANPAGER) | Syntax-highlighted man pages |
| `ls` | `eza` | Icons, colors, directories sorted first |
| `ll` | `eza -la` | Long list with git status, relative times, clickable filenames |
| `lt` | `eza --tree` | Tree view (2 levels), directories first |
| `diff a b` | `delta` | Side-by-side with syntax highlighting |
| `ps` | `procs` | Color-coded, searchable |
| `du` | `dust` | Visual disk usage tree |
| `top` | `btm` | Modern system monitor TUI |
| `curl url` | `xh` | Pretty HTTP output, simpler syntax |
| `dig host` | `doggo` | Modern DNS with DoH/DoT support |
| `sed 'x' 'y'` | `sd` | Intuitive regex, no escape hell |
| `find pattern` | `fd` | Simple, fast, respects .gitignore |
| `rm file` | `trash` | Moves to trash instead of deleting |
| `v` / `vi` / `vim` | `nvim` | Neovim |

### Shortcuts

| Command | Action |
|---------|--------|
| `g` | lazygit |
| `ld` | lazydocker |
| `y` | yazi file manager (cd on exit) |
| `up` | Update all packages and tools (topgrade) |
| `help <cmd>` | Quick help: tldr with man fallback |
| `cheat [term]` | Search cheatsheet (or render with glow if no term) |
| `abbrs` | Fuzzy search all fish abbreviations |
| `Ctrl+S` | Toggle sudo prefix on current command |

### Workflow Functions

| Command | Action |
|---------|--------|
| `tdd py -- pytest` | Watch files and re-run tests on change |
| `gbr` | Fuzzy switch git branch (sorted by recent, with log preview) |
| `gwt [branch]` | Jump to the worktree holding a branch, even mid-rebase (fzf when ambiguous) |
| `zp` | Fuzzy jump to a project directory (scored, with tree preview) |
| `recent [dur]` | Find files changed within duration (default: 1day, uses fd) |
| `bloat [size]` | Find files larger than size (default: 10MB, uses fd) |
| `fkill` | Fuzzy find and kill a process |
| `zl dev` | Start zellij with a named layout |
| `zl` | List available zellij layouts |
| `rec` | Record terminal session as GIF (vhs) |
| `rec file.tape` | Run an existing vhs tape file |
| `env-encrypt` | Encrypt `.env` file with sops+age |
| `env-encrypt secrets.yaml` | Encrypt a specific file |
| `env-decrypt file.enc` | Decrypt sops-encrypted file |

### Smart Functions

| Command | Action |
|---------|--------|
| `api GET url` | HTTP request with auto-formatted JSON output |
| `jqi file.json` | Interactive JSON explorer (jnv) |
| `md README.md` | Render markdown in terminal |
| `watch -e rs cargo test` | Re-run command on file changes |
| `bench 'cmd1' 'cmd2'` | Benchmark and compare commands |
| `stats` | Show lines of code + disk usage for current project |
| `encrypt file` | Encrypt file with age (password prompt) |
| `decrypt file.age` | Decrypt age-encrypted file |
| `backup ~/dir` | Backup with restic |
| `dive-last` | Inspect most recent container image layers |
| `box` | Interactive distrobox picker (gum) |
| `box ubuntu` | Enter or create an Ubuntu distrobox |
| `use node@20` | Set tool version via mise |

### Devcontainer Functions

| Command | Action |
|---------|--------|
| `dn <name>` | Create new devcontainer project (prompts with gum if no name given) |
| `dc` | devcontainer up (with nvim config mounted) |
| `db` / `df` / `de` | devcontainer exec bash / fish / nvim |
| `dr` | devcontainer up (rebuild from scratch) |

### Dotfile Management

| Command | Action |
|---------|--------|
| `udot` | Interactive commit + push dotfiles (gum confirm + custom message), then stow |
| `uva` | Activate `.venv/bin/activate.fish` |
| `reload` | Reload fish config (optional `--zellij` to reset zellij session) |

### Shell Integrations & Keybindings

| Shortcut | Tool | Action |
|----------|------|--------|
| `Alt+T` | fzf + fd | Fuzzy find files with bat/eza preview (rebound from Ctrl+T for Zellij) |
| `Alt+C` | fzf + fd | Fuzzy cd into directory with tree preview |
| `Ctrl+/` | fzf | Toggle preview in any fzf picker |
| `Ctrl+R` | Atuin | Fuzzy search shell history (directory-scoped on up-arrow, workspace-aware) |
| `z <dir>` | zoxide | Jump to frecent directory |
| `zi` | zoxide | Interactive directory picker (with tree preview) |

### Active Shell Integrations

These activate automatically in every fish session:

- **zoxide** — `z` / `zi` directory jumping
- **fzf** — `Alt+T` (files), `Alt+C` (cd), `Ctrl+R` (history via atuin)
- **atuin** — shell history sync and search
- **mise** — auto-activates tool versions per project (`.mise.toml`)
- **starship** — cross-shell prompt

---

## Zellij

Leader-free navigation. Autolock engages when nvim/vim/claude/git/fzf/zoxide/atuin are running.

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
| `zj ide [name]` | IDE session in `.worktrees/<name>` (creates branch + worktree if missing; no arg = fzf over existing worktrees) |
| `zj ide done <name>` | Tear down: kill session, remove worktree, delete branch (refuses dirty/unmerged) |

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

Start zellij with a layout: `zellij layout dev`

| Layout | Description |
|--------|-------------|
| `dev` | Editor (70%) + terminal + lazygit sidebar |
| `fullstack` | Editor + frontend/backend panes + logs tab |
| `ide` | Claude Code (58%) + Neogit overview + shell, for branch worktrees (via `zj ide`) |
| `monitor` | 4-pane grid for monitoring |
| `sics` | Remote development on r2d2 (2 remote shells + remote neovim editor) |

#### ide layout (Claude Code on a worktree)

`zj ide <name>` pairs a branch worktree with a session: Claude Code left (58%),
Neogit right (auto-refreshing every 2s via `nvim/lua/custom/neogit_watch.lua` —
Neogit's own watcher only sees `.git/`, not edits Claude makes), small shell
below it. Claude Code hooks label the claude pane with its state: 🤖 working,
💬 waiting for input, ✅ done. The claude pane autolocks zellij so Claude's
Ctrl chords work; leave it with the mouse or `Alt+Z` then a nav key.

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

## Yazi

Terminal file manager with vim-style navigation. Launch with `y` (fish) or `Alt+Y` (zellij). Theme: Catppuccin Mocha. Plugins: git status, smart-enter, smart-filter, mime-ext.

### Navigation

| Shortcut | Action |
|----------|--------|
| `h/l` | Parent / enter directory (l = smart-enter: opens files too) |
| `j/k` | Move down / up |
| `H/L` | Directory history back / forward |
| `z` | fzf jump to any directory |
| `Z` | Zoxide jump (uses your frecency database) |
| `!` | Open fish shell in current directory |

### Search & Filter

| Shortcut | Action |
|----------|--------|
| `s` | **Search filenames** recursively (fd) |
| `S` | **Search file contents** recursively (ripgrep) |
| `f` | Smart filter (live filter as you type) |
| `/` | Incremental find in current directory |

### Selection & File Operations

| Shortcut | Action |
|----------|--------|
| `Space` | Toggle selection on hovered file |
| `v` | Visual mode (select range by moving) |
| `Ctrl+A` | Select all |
| `y` / `x` | Yank (copy) / yank (cut) |
| `p` / `P` | Paste / paste with overwrite |
| `d` / `D` | Trash / permanent delete |
| `a` | Create file (add `/` suffix for directory) |
| `r` | Rename (bulk rename in editor when multiple selected) |
| `cc` `cd` `cf` | Copy: full path / directory / filename |

### Display

| Shortcut | Action |
|----------|--------|
| `.` | Toggle hidden files |
| `,m` `,s` `,e` | Sort by modified / size / extension |
| `ms` `mp` `mm` | Linemode: show size / permissions / modified |
| `K/J` | Scroll preview up / down |
| `Tab` | Spot view (detailed file metadata) |
| `t` | New tab, `[`/`]` to switch |
| `w` | Task manager (background operations) |

### Bookmarks

| Shortcut | Destination |
|----------|-------------|
| `g d` | `~/dotfiles` |
| `g p` | `~/Projects` |
| `g c` | `~/.config` |
| `g D` | `~/Downloads` |
| `g o` | `~/Documents` |

Config and code files (`.md`, `.json`, `.toml`, `.yaml`, `.kdl`, `.lua`, `.fish`, `.sh`) open directly in nvim. Git status indicators show inline next to filenames.

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

The `bash` and `claude` packages are stowed separately to `~` (for `~/.bashrc`
and `~/.claude/`).

Stow runs **without** `--adopt`. Adopt reverses the data flow — it pulls
whatever is on disk back into the repo, and with the sync timer running that
gets committed and pushed automatically. That is how the tracked nvim config
was clobbered in March 2026. If pulling on-disk files in really is what you
want, run `just adopt`, which does it explicitly and then shows you the diff.

### Automatic sync

`dotfiles-sync.timer` runs every 15 minutes and:

1. waits for the network (the timer fires the moment the user slice thaws after suspend),
2. **aborts if more than 25 files are deleted** — a wiped tree must never propagate,
3. **scans staged content with gitleaks and aborts on any finding**,
4. commits, rebases onto origin, pushes,
5. runs `just deploy` (stow + per-machine zellij config + omarchy skill link).

Failures surface in the next shell via the greeting in
`fish/conf.d/dotfiles-sync-check.fish`; the log is
`~/.local/state/dotfiles-sync.log`.

### Secret handling

The repo is public and pushed unattended, so **nothing secret may live in the
working tree** — not even gitignored. `.gitignore` is a convenience, not a
security control: one careless edit and the next tick publishes the file.

Three layers, in order of how much they actually catch:

| Layer | Covers | Limits |
|-------|--------|--------|
| Keep secrets out of the tree | Everything | Requires discipline; the copr API token lives at `~/.config/copr` as a real 0600 file, deliberately *not* stowed |
| `gitleaks` in `dotfiles-sync.sh` | The automated commit path | Fails closed — no gitleaks, no sync |
| `gitleaks` via pre-commit hook | Hand-made commits and `udot` | Bypassed by `--no-verify` |

GitHub secret scanning and push protection are enabled, but on a free public
repo they match **provider-prefixed** tokens only (`ghp_`, `AKIA`, `sk-`…).
They would not have caught the copr token — which is why `.gitleaks.toml` adds
a rule for config-style `token = …` assignments that the default ruleset misses.

Run `just doctor` to confirm both scanners are present; the fish greeting does
this weekly.

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
├── atuin/          # Shell history config (fuzzy search, directory filtering, workspace mode)
├── bash/           # Bash config (~/.bashrc, stowed to ~) — fallback shell only
├── bat/            # bat config (style, syntax mappings, man pager)
├── claude/         # Claude Code config (stowed to ~): settings, hooks, agents, rules, skills
├── docs/           # Notes and proposals — not config, never stowed
├── fish/           # Fish shell config, plugins, functions
├── ghostty/        # Terminal emulator config
├── hypr/           # Hyprland overrides on top of Omarchy (bindings, looknfeel, scratchpads, privacy, power)
├── lazygit/        # Git TUI config
├── nvim/           # Neovim config (Kickstart-based)
│   ├── init.lua    # Main config (keymaps, LSP, plugins)
│   └── lua/
│       ├── custom/plugins/   # fzf-lua, snacks, noice, neogit, diffview, oil, flash, trouble, grug-far
│       └── kickstart/plugins/ # gitsigns, lint, debug, autopairs, remote
├── omarchy/        # Desktop shell: bar layout (shell.json), glass tokens (shell.toml), QML plugins, hooks, launcher menu rows
├── ripgrep/        # ripgrep config (smart-case, hidden files, max-columns)
├── scripts/        # dotfiles-sync.sh (the 15-minute timer) and helpers; solar/ is the solar wallpaper with its tests, backgrounds/ the picker and Bluefin import
├── server/         # Podman quadlets for the homeserver (plex, sonarr, radarr)
├── starship.toml   # Shell prompt config (nordfox palette)
├── systemd/        # User units: dotfiles-sync, backup, readest
├── yazi/           # File manager config (catppuccin flavor, git/smart-enter/smart-filter plugins)
├── zellij/         # Zellij config + layouts
│   ├── config.kdl        # pneuma
│   ├── config.r2d2.kdl   # homeserver variant, selected by `just configure-zellij`
│   ├── themes/           # nordfox.kdl — shared by both configs
│   └── layouts/          # dev, fullstack, ide, monitor, sics
├── .gitleaks.toml  # Secret-scanning rules for the sync gate and pre-commit hook
├── Brewfile        # Homebrew packages
└── justfile        # Setup/install/deploy recipes
```
