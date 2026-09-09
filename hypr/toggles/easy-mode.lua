-- Easy mode: a floating, mouse-driven desktop for someone who expects macOS.
--
-- This file is never loaded from ~/.config/hypr. `hypr/bin/easy-mode` copies it
-- into ~/.local/state/omarchy/toggles/hypr/, which Omarchy sources after every
-- other config file (default/hypr/toggles.lua), and deletes the copy again to
-- turn easy mode off. Being sourced last is the whole trick: every setting here
-- is an override of something set earlier, and `hyprctl reload` on a config
-- without the copy rebuilds the session from scratch, so nothing has to be
-- undone by hand -- not the rules, not the binds, not the config values.
--
-- The one piece that does not live here is the window-button layout, which is
-- a GTK setting rather than a compositor one. The script owns that.

-- Nothing tiles. Anonymous window rules are last-match-wins and this file is
-- sourced last, so this beats every rule Omarchy set earlier -- including the
-- `tile = true` it puts on Chromium-based browsers (default/hypr/apps/browser.lua).
o.window(".*", { float = true })

-- Omarchy suppresses client-initiated maximize requests for every window
-- (default/hypr/windows.lua), which is right for a tiled desktop and wrong
-- here: it leaves the green titlebar button and a titlebar double-click doing
-- nothing. A floating window can maximize without disturbing a layout.
o.window(".*", { suppress_event = "" })

-- Hyprland places a new floating window at the centre of the work area and has
-- no cascade, so this is mostly making the placement explicit; it also recentres
-- the windows Omarchy's own rules would have positioned for a tiled layout.
o.window(".*", { center = true })

hl.config({
  general = {
    -- Resize by dragging any edge or corner, no modifier held. The grab area
    -- carries the whole gesture on its own here: looknfeel.lua draws a 1px
    -- border, which is far too thin to hit with a mouse.
    resize_on_border = true,
    extend_border_grab_area = 20,
    hover_icon_on_border = true,
  },

  input = {
    -- Click to focus. 2 rather than 0 leaves the *pointer's* focus attached to
    -- whatever is under it, so the scroll wheel still scrolls an unfocused
    -- window without raising it -- which is what macOS does too.
    follow_mouse = 2,
  },
})

-- Minimize. Hyprland has no minimize: XDGShell records xdg_toplevel.set_minimized
-- and nothing consumes it (hyprwm/Hyprland#3984), so a titlebar minimize button
-- is a dead control and `easy-mode` takes it out of the GTK button layout. A
-- special workspace is the working substitute -- the window is parked out of
-- sight, and the dock's icon keeps a dot and brings it back on click.
o.bind("SUPER + M", "Minimize window",
  hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
o.bind("SUPER + ALT + M", "Show minimized windows",
  hl.dsp.workspace.toggle_special("minimized"))

-- The dock is a bottom layer surface and overlaps windows, so it gets the same
-- frosted backdrop as the other popup surfaces. Not `xray`, which the bar uses:
-- that samples the wallpaper only, and would blank whatever the dock covers.
-- `blur_popups` matters as much as `blur` here: the icons' right-click menu is
-- an xdg_popup of this surface, not a layer of its own, and the popup palette
-- is 0.72 alpha (omarchy/shell.toml) on the assumption of a frosted backdrop.
-- Without it the menu is 28% see-through over raw desktop and hard to read.
hl.layer_rule({ match = { namespace = "pneuma-dock" }, blur = true, blur_popups = true, ignore_alpha = 0.5 })
