-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

-- This file is stowed on every machine, so per-host tuning keys off the
-- hostname. Hosts not listed fall back to scale 1.
local host_monitor_scale = { fedora = 1.5 }

-- /proc, not /etc/hostname: some hosts (this fedora install) leave the static
-- hostname unset and run on the transient fallback name.
local hostname = ""
do
  local f = io.open("/proc/sys/kernel/hostname")
  if f then
    hostname = f:read("*l") or ""
    f:close()
  end
end

local omarchy_monitor_scale = host_monitor_scale[hostname] or 1

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
