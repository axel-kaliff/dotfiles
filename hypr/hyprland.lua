-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Float yazi like Omarchy's other TUI windows (btop, terminal). The app-id
-- comes from omarchy-launch-tui's default: org.omarchy.<command>.
o.window("org.omarchy.yazi", { tag = "+floating-window" })

-- Loupe replaces imv as the image viewer (imv has no EL10 package). Omarchy's
-- media rules match imv by class, so mirror them: float it, and drop the
-- default transparency -- a translucent window misrepresents the image.
o.window("org.gnome.Loupe", { tag = "+floating-window" })
o.window("org.gnome.Loupe", { tag = "-default-opacity" })
o.window("org.gnome.Loupe", { opacity = "1 1" })
