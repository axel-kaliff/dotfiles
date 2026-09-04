# Zellij Cheat Sheet

Rendered into the keybindings popup by `omarchy-menu-zellij-keybindings`
(SUPER + ALT + K). Edit this file — the popup keeps no second copy.

Verified against `config.kdl`, which sets `clear-defaults=true`, so every
binding below is one this config states explicitly.

## Modes

| `Ctrl g` | Locked — keys pass through to the TUI; Ctrl g again to leave |
| `Ctrl p` | Pane mode — leave with Ctrl p, Esc or Ctrl [ |
| `Ctrl t` | Tab mode — leave with Ctrl t, Esc or Ctrl [ |
| `Ctrl n` | Resize mode — leave with Ctrl n, Esc or Ctrl [ |
| `Ctrl m` | Move mode — leave with Ctrl h, Esc or Ctrl [ (not Ctrl m) |
| `Ctrl s` | Scroll mode — leave with Ctrl s, Esc or Ctrl [ |
| `Ctrl o` | Session mode — leave with Ctrl o, Esc or Ctrl [ |

## Global — everywhere except locked mode

| `Ctrl h` / `Ctrl l` | Focus pane left/right, crossing tab edges |
| `Ctrl j` / `Ctrl k` | Focus pane down/up |
| `Alt Left` / `Alt Right` | Focus pane left/right, crossing tab edges |
| `Alt Down` / `Alt Up` | Focus pane down/up |
| `Alt n` | New pane |
| `Alt f` | Toggle floating panes |
| `Alt [` / `Alt ]` | Previous/next swap layout |
| `Alt i` / `Alt o` | Move tab left/right |
| `Alt p` | Toggle pane in group |
| `Alt Shift p` | Toggle group marking |
| `Alt q` | Clear terminal |
| `Alt +` / `Alt =` | Resize increase |
| `Alt -` | Resize decrease |
| `Ctrl g` | Lock the session |

## Global — these keep working while locked

Autolock locks the session whenever nvim, git, fzf, zoxide or atuin has focus,
so their Ctrl chords reach the TUI. These live in `shared` rather than
`shared_except "locked"`, which is what keeps a locked session navigable — Alt
is free inside a TUI, Ctrl is not.

| `Alt h` / `Alt l` | Focus pane left/right, crossing tab edges |
| `Alt j` / `Alt k` | Focus pane down/up |
| `Alt w` | Session manager |
| `Alt Shift z` | Re-enable autolock |
| `Alt z` | Lock now and tell autolock to stand down |

## Plugins

| `Ctrl y` | room — fuzzy tab switcher, number keys quick-jump |
| `Alt /` | zellij-forgot — searchable overlay of every keybind |
| `Alt b` | harpoon — pane bookmarks |
| `Alt m` | monocle — fuzzy file and content finder |
| `Alt t` | multitask — run `.multitask` jobs in parallel |

## Pane mode — Ctrl p

| `h` `j` `k` `l` | Move focus |
| `Left` `Down` `Up` `Right` | Move focus |
| `n` | New pane |
| `d` | New pane below |
| `r` | New pane right |
| `s` | New stacked pane |
| `f` | Toggle fullscreen |
| `Shift f` | Toggle fullscreen with the UI bars hidden (zen) |
| `e` | Toggle embedded / floating |
| `w` | Toggle floating panes |
| `c` | Rename pane |
| `i` | Toggle pane pinned |
| `z` | Toggle pane frames |
| `p` | Switch focus |
| `;` | Focus last pane |

## Tab mode — Ctrl t

| `h` / `k` | Previous tab |
| `j` / `l` | Next tab |
| `Left` / `Up` | Previous tab |
| `Down` / `Right` | Next tab |
| `1`-`9` | Jump to tab N |
| `n` | New tab inheriting the focused pane's cwd |
| `r` | Rename tab |
| `x` | Close tab |
| `s` | Toggle sync — typing reaches every pane in the tab |
| `b` | Break the focused pane out into its own tab |
| `[` / `]` | Break pane to the tab left/right |
| `Tab` | Toggle last tab |

## Resize mode — Ctrl n

| `h` `j` `k` `l` | Increase size in that direction |
| `Left` `Down` `Up` `Right` | Increase size in that direction |
| `H` `J` `K` `L` | Decrease size in that direction |
| `+` / `=` | Increase overall |
| `-` | Decrease overall |

## Move mode — Ctrl m

| `h` `j` `k` `l` | Move pane in that direction |
| `Left` `Down` `Up` `Right` | Move pane in that direction |
| `n` / `Tab` | Move pane forward |
| `p` | Move pane backwards |

## Scroll mode — Ctrl s

| `j` / `k` | Scroll down/up a line |
| `Down` / `Up` | Scroll down/up a line |
| `d` / `u` | Half page down/up |
| `Ctrl f` / `Ctrl b` | Page down/up |
| `l` / `h` | Page down/up |
| `Right` / `Left` | Page down/up |
| `PageDown` / `PageUp` | Page down/up |
| `Ctrl c` | Jump to the bottom and return to normal |
| `[` / `]` | Jump to previous/next shell prompt (OSC 133) |
| `m` | Select the command at the scroll position and its output |
| `c` | Copy the last command's output |
| `e` | Open the scrollback in nvim |
| `s` | Start a search |

## Search — s from scroll mode

Type the query, press Enter to search, then:

| `n` / `p` | Next/previous match |
| `c` | Toggle case sensitivity |
| `w` | Toggle wrap |
| `o` | Toggle whole-word matching |
| `Esc` / `Ctrl c` | Back to scroll mode |

## Session mode — Ctrl o

| `d` | Detach — drops back to the plain shell |
| `w` | Session manager |
| `c` | Configuration |
| `l` | Layout manager |
| `p` | Plugin manager |
| `a` | About |
| `[` | Descend into the nested guest session |
| `]` | Ascend back to the host session |
| `f` | Toggle guest-session fullscreen |

## Nested sessions

Since zellij 0.45 nesting is built in. `nested_session_handling "descend"` in
`config.kdl` means that when a guest zellij announces itself over the pty — the
usual case being `zj remote` — the host routes keys straight into it instead of
asking. You are then typing in the guest, and the host's mode keys are out of
the way.

| `Ctrl o ]` | Ascend — hand keys back to the host session |
| `Ctrl o [` | Descend — hand keys back to the guest |
| `Ctrl o f` | Toggle the guest fullscreen inside the host |
| `Ctrl g` | Fallback for a pre-0.45 remote: lock the host so its keys pass through |

The guest's own config must bind `FocusHostSession` (`]` here). That binding
lives in the guest, not the host, so a guest without it is a session you can
descend into but not climb out of, short of detaching.

Both ends need zellij >= 0.45. A 0.45 client also cannot attach to a session
still running under a 0.44 server, so after upgrading a remote, each of its
sessions needs a kill and re-create before it will accept a connection.

Other values for `nested_session_handling`: `ask` (the default), `fullscreen`,
`never`.

## Harpoon panel — inside Alt b

| `a` | Bookmark the current pane |
| `A` | Bookmark every pane |
| `d` | Remove bookmark |
| `Enter` / `l` | Jump to the bookmarked pane |
| `j` / `k` | Move down/up the list |

## zj — session helper

| `zj` | Attach to, or create, a session named after the current directory |
| `zj <name>` | Attach to, or create, that session |
| `zj ls` | List sessions |
| `zj attach <name>` | Attach, creating if needed |
| `zj kill <name>` | Kill a session |
| `zj layout <session> <layout>` | Start with a layout and remember the choice |
| `zj reset <session>` | Kill, delete and relaunch with its recorded layout |
| `zj ide [name]` | Branch-worktree IDE session — claude, neogit and a shell |
| `zj ide done <name>` | Tear that IDE session and its worktree down |
| `zj remote [host] [session]` | SSH-attach to a remote session (default r2d2/main) |
| `zj web [host] [port]` | Tunnel to the remote web server (default r2d2:8082) |

Layouts in `layouts/`: `dev`, `fullstack`, `ide`, `monitor`, `sics`.

## zellij — the commands underneath

| `zellij` | Start a new session with a generated name |
| `zellij -s <name>` | Start a named session |
| `zellij attach -c <name>` | Attach, creating if absent |
| `zellij list-sessions` | List sessions and their state |
| `zellij kill-session <name>` | Kill one session |
| `zellij kill-all-sessions` | Kill every session |
| `zellij delete-session <name>` | Delete a killed session's saved state |
| `zellij -l <layout>` | Start with a layout |
| `zellij run -- <cmd>` | Run a command in a new pane |
| `zellij run -f -- <cmd>` | Run a command in a floating pane |
| `zellij edit <file>` | Open a file in a new pane with $EDITOR |
| `zellij action <action>` | Drive the running session from the shell |
| `zellij setup --dump-config` | Print the default config |
| `zellij setup --check` | Report the config and directories in use |
