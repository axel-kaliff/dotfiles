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
-- Loaded optionally, the way Omarchy loads its own optional pieces. A plain
-- require() that cannot find its module aborts the rest of this file, so a
-- module that has been pulled but not yet stowed -- the sync timer pulls before
-- it deploys, and these files are symlinks into the repo -- would take privacy,
-- power and the toggles down with it rather than just itself. A module missing
-- here always means the deploy failed; the dotfiles-sync notification is what
-- tells you that.
local require_optional = require("default.hypr.require_optional")

require_optional.module("hypr.monitors")
require_optional.module("hypr.input")
require_optional.module("hypr.bindings")
require_optional.module("hypr.looknfeel")
require_optional.module("hypr.autostart")
require_optional.module("hypr.scratchpads")
require_optional.module("hypr.privacy")
-- After looknfeel: it corrects the blur values looknfeel just set.
require_optional.module("hypr.power")
-- After looknfeel: it saves the scroll settings it overrides.
require_optional.module("hypr.center")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- The "Edit" action on a screenshot notification opens Gradia (see
-- hypr/bin/gradia-edit); Omarchy's default editor has no EL10 package.
hl.env("OMARCHY_SCREENSHOT_EDITOR", os.getenv("HOME") .. "/.config/hypr/bin/gradia-edit")

-- Float yazi like Omarchy's other TUI windows (btop, terminal). The app-id
-- comes from omarchy-launch-tui's default: org.omarchy.<command>.
o.window("org.omarchy.yazi", { tag = "+floating-window" })

-- Loupe replaces imv as the image viewer (imv has no EL10 package). Omarchy's
-- media rules match imv by class, so mirror them: float it, and drop the
-- default transparency -- a translucent window misrepresents the image.
o.window("org.gnome.Loupe", { tag = "+floating-window" })
o.window("org.gnome.Loupe", { tag = "-default-opacity" })
o.window("org.gnome.Loupe", { opacity = "1 1" })

-- Slack and Thunderbird each keep a workspace of their own. Not `silent`:
-- opening either one, or a Thunderbird compose window, takes you there rather
-- than opening it out of sight. Both autostart, so login ends on one of them.
o.window("com.slack.Slack", { workspace = "9" })
o.window("org.mozilla.thunderbird_esr", { workspace = "8" })
-- The obsidian-work vault gets 7. Every Obsidian window shares one class, so
-- the vault is told apart by the title, which names it from the moment it opens.
o.window({ class = "md.obsidian.Obsidian", initial_title = ".*obsidian-work - Obsidian.*" }, { workspace = "7" })
