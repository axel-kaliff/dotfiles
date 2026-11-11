-- Easy mode: a floating, mouse-driven desktop for someone who expects macOS.
--
-- This file is never loaded from ~/.config/hypr. `hypr/bin/easy-mode` copies it
-- into ~/.local/state/omarchy/toggles/hypr/, which Omarchy sources after every
-- other config file (default/hypr/toggles.lua), and deletes the copy again to
-- turn easy mode off. Being sourced last is the whole trick: every setting here
-- is an override of something set earlier, and `hyprctl reload` on a config
-- without the copy rebuilds the session from scratch, so nothing has to be
-- undone by hand -- not the rules, not the config values.
--
-- The one piece that does not live here is the window-button layout, which is
-- a GTK setting rather than a compositor one. The script owns that.

-- hypr/bin/easy-mode writes the floating default into 4.5's workspace-layouts
-- state, where the dock and the bar read layouts from.

-- Omarchy suppresses client-initiated maximize requests for every window
-- (default/hypr/windows.lua), which is right for a tiled desktop and wrong
-- here: it leaves the green titlebar button and a titlebar double-click doing
-- nothing. A floating window can maximize without disturbing a layout.
o.window(".*", { suppress_event = "" })

hl.config({
  general = {
    -- Resize by dragging any edge or corner, no modifier held. The grab area
    -- carries the whole gesture on its own here: looknfeel.lua draws a 1px
    -- border, which is far too thin to hit with a mouse.
    resize_on_border = true,
    extend_border_grab_area = 20,
    hover_icon_on_border = true,
  },
})

-- The dock is a bottom layer surface and overlaps windows, so it gets the same
-- frosted backdrop as the other popup surfaces. Not `xray`, which the bar uses:
-- that samples the wallpaper only, and would blank whatever the dock covers.
hl.layer_rule({ match = { namespace = "omarchy-dock" }, blur = true, ignore_alpha = 0.5 })
