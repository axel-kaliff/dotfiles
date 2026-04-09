# Zellij Configuration

Zellij config for r2d2, using the **terafox** theme with rounded pane frames.

## Plugins

| Plugin | Description | Keybind |
|--------|-------------|---------|
| [zjstatus](https://github.com/dj95/zjstatus) | Custom status bar | Loaded via layout |
| [zellij-autolock](https://github.com/fresh2dev/zellij-autolock) | Auto-locks when nvim/git/fzf/zoxide/atuin detected | Automatic |
| [room](https://github.com/rvcas/room) | Fuzzy tab switcher | `Ctrl y` |
| [zellij-forgot](https://github.com/karimould/zellij-forgot) | Keybind reminder overlay | `Alt /` |
| [harpoon](https://github.com/Nacho114/harpoon) | Bookmark and jump between panes | `Alt b` |
| [monocle](https://github.com/imsnif/monocle) | Fuzzy file/content finder | `Alt m` |
| [multitask](https://github.com/leakec/multitask) | Mini CI - run parallel tasks | `Alt t` |

Plugin `.wasm` files live in `plugins/` and are referenced as `file:~/.config/zellij/plugins/<name>.wasm`.

## Plugin Usage

### room - Fuzzy Tab Switcher

Press `Ctrl y` to open. Start typing to filter tabs. With `quick_jump` enabled, press a number key to jump directly to that tab.

### zellij-forgot - Keybind Reminder

Press `Alt /` to open a floating overlay showing all your keybindings. Auto-loads bindings from your Zellij config. Fuzzy-search by typing.

### harpoon - Pane Bookmarks

Press `Alt b` to open the harpoon panel. Inside the panel:

| Key | Action |
|-----|--------|
| `a` | Add current pane to bookmarks |
| `A` | Add all panes |
| `d` | Remove bookmark |
| `Enter` / `l` | Switch to bookmarked pane |
| `j` / `k` | Navigate up/down |

### monocle - Fuzzy File Finder

Press `Alt m` to open. Search for file names or file contents across your project. Select a result to open it in your editor.

### multitask - Mini CI Runner

Press `Alt t` to open. Create a `.multitask` file in your project root to define tasks:

```
# Each line is a command to run in parallel
cargo test
cargo clippy
cargo fmt --check
```

Tasks run in parallel and results are displayed inline.

## Mode Keybinds

Enter a mode with its prefix key, then use mode-specific keys. Press `Esc` to return to normal mode.

| Mode | Enter with | Exit with |
|------|-----------|-----------|
| Locked | `Ctrl g` | `Ctrl g` |
| Pane | `Ctrl p` | `Ctrl p` / `Esc` |
| Tab | `Ctrl t` | `Ctrl t` / `Esc` |
| Resize | `Ctrl n` | `Ctrl n` / `Esc` |
| Move | `Ctrl m` | `Esc` |
| Scroll | `Ctrl s` | `Ctrl s` / `Esc` |
| Session | `Ctrl o` | `Ctrl o` / `Esc` |

## Installation

Symlink to `~/.config/zellij/`:

```bash
ln -sf ~/dotfiles/zellij/config.kdl ~/.config/zellij/config.kdl
ln -sf ~/dotfiles/zellij/plugins ~/.config/zellij/plugins
ln -sf ~/dotfiles/zellij/layouts ~/.config/zellij/layouts
```
