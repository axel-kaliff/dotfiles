-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Vim-style window navigation: SUPER + h/j/k/l focuses, + SHIFT swaps.
-- Displaced defaults move to the same key with ALT added. SUPER + ALT + K was
-- already the terminal-multiplexer cheatsheet, so the Omarchy keybindings menu
-- takes SHIFT + ALT.
hl.unbind("SUPER + J") -- was: Toggle window split
hl.unbind("SUPER + K") -- was: Keybindings
hl.unbind("SUPER + L") -- was: Toggle workspace layout

o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + SHIFT + ALT + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Cheat sheet on SUPER + ALT + K shows zellij, not tmux -- zellij is the
-- multiplexer here. Rendered from ~/.config/zellij/CHEATSHEET.md, which is the
-- same file the dotfiles repo carries.
hl.unbind("SUPER + ALT + K") -- was: Tmux keybindings
o.bind("SUPER + ALT + K", "Zellij keybindings",
  os.getenv("HOME") .. "/.config/hypr/bin/omarchy-menu-zellij-keybindings")

o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- Input language switching on SUPER + SHIFT + SPACE (cycles kb_layout, see
-- input.lua); the top-bar toggle it displaces moves to SUPER + SHIFT + T.
hl.unbind("SUPER + SHIFT + SPACE") -- was: Toggle top bar
o.bind_toggle("SUPER + SHIFT + T", "Toggle top bar", "bar")
o.bind("SUPER + SHIFT + SPACE", "Next keyboard layout", "hyprctl switchxkblayout all next")

-- File manager: yazi (TUI) instead of Nautilus.
-- Nautilus stays installed as the GUI fallback -- it is still the xdg handler
-- for inode/directory, so "open containing folder" from other apps uses it.
hl.unbind("SUPER + SHIFT + F")       -- was: File manager (nautilus)
hl.unbind("SUPER + ALT + SHIFT + F") -- was: File manager cwd (nautilus-cwd)

-- Persistent session: yazi-session restores the last instance's tabs
-- (auto-saved on quit by the projects.yazi plugin, see yazi/init.lua).
o.bind("SUPER + SHIFT + F", "File manager",
  "omarchy-launch-or-focus-tui --app-id=org.omarchy.yazi "
  .. os.getenv("HOME") .. "/.config/hypr/bin/yazi-session")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)",
  os.getenv("HOME") .. "/.config/hypr/bin/yazi-cwd")

-- MX Keys screenshot button. The keyboard sends the Windows snipping-tool
-- combo (Left Win + Shift + S) in firmware; altwin:swap_lalt_lwin in input.lua
-- turns Left Win into Alt, so Hyprland actually sees ALT + SHIFT + S. Binding
-- SUPER + SHIFT + S instead would never fire (and is Google Maps by default).
o.bind("ALT + SHIFT + S", "Screenshot (MX Keys button)", "omarchy-capture-screenshot")

-- Jump to whichever window is asking for attention (urgent hint), or back to
-- the previous window when nothing is.
o.bind("SUPER + U", "Focus urgent window", hl.dsp.focus({ urgent_or_last = true }))

hl.config({
  binds = {
    -- SUPER + n on the workspace you are already on returns to the last one.
    workspace_back_and_forth = true,
    -- SUPER + h/j/k/l keep cycling windows behind a fullscreen one instead of
    -- being swallowed by it.
    movefocus_cycles_fullscreen = true,
  },
})

-- Resize mode: SUPER + R, then h/j/k/l grow the window towards that side
-- (held keys repeat), Escape or any other key leaves. The stock MINUS/EQUAL
-- chords still work; this is the vim-shaped route to the same thing. The OSD
-- shows the mode while it is on, so a stuck submap is never a mystery.
hl.bind("SUPER + R", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
  local step = 40
  hl.bind("h", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
  hl.bind("j", hl.dsp.window.resize({ x = 0, y = step, relative = true }), { repeating = true })
  hl.bind("k", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
  hl.bind("l", hl.dsp.window.resize({ x = step, y = 0, relative = true }), { repeating = true })
  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("catchall", hl.dsp.submap("reset"))
end)

hl.on("keybinds.submap", function(name)
  if name == "resize" then
    hl.exec_cmd([[omarchy-shell -q osd show '{"icon":"⤢","message":"Resize  h j k l","duration":0}']])
  else
    hl.exec_cmd("omarchy-shell -q osd close")
  end
end)
