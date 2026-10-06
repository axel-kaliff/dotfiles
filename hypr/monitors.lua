-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Pneuma default: the laptop panel sits centered below any external monitor.
-- Expressed as "externals go centered above the laptop" rather than the other
-- way round: Hyprland resolves eDP-1 first, so it has to be the fixed anchor
-- or the auto placement has nothing to center against.
hl.monitor({ output = "", mode = "preferred", position = "auto-center-up", scale = omarchy_monitor_scale })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })

-- Dell U4025QW: 5120x2160@120 needs USB-C/Thunderbolt (DP 1.4 + DSC). i915 has
-- no HDMI 2.1 FRL yet, so over HDMI Hyprland falls back to 5120x2160@30.
hl.monitor({ output = "desc:Dell Inc. DELL U4025QW 4XMHC34", mode = "5120x2160@120", position = "auto-center-up", scale = omarchy_monitor_scale })
