-- Battery-aware glass. Dual-Kawase blur is the one expensive part of the
-- material: on battery the frost narrows from three passes at 12px (168px
-- reach) to two at 8px (48px reach), which keeps the look while roughly
-- halving the blur work per frame. Shadows stay: they are cheap and they are
-- the focus cue. Values return to looknfeel's when the charger is back.
--
-- Polled from inside the compositor, so there is no daemon, no udev rule and
-- nothing that has to find the Hyprland socket: a sysfs read every ten
-- seconds. `hyprctl reload` re-runs this file in the same Lua state, so the
-- previous timer is stopped before a new one is armed.
local AC_ONLINE = "/sys/class/power_supply/AC/online"

local blur_profiles = {
  ac = { size = 12, passes = 3 },
  battery = { size = 8, passes = 2 },
}

local function on_ac()
  local file = io.open(AC_ONLINE, "r")
  if not file then
    return true
  end
  local state = file:read("*l")
  file:close()
  return state == "1"
end

local function apply_blur(ac)
  hl.config({ decoration = { blur = blur_profiles[ac and "ac" or "battery"] } })
end

if _G.pneuma_power_timer then
  _G.pneuma_power_timer:set_enabled(false)
end

-- looknfeel.lua just set the AC values; correct them right away if unplugged.
local current = on_ac()
if not current then
  apply_blur(false)
end

_G.pneuma_power_timer = hl.timer(function()
  local ac = on_ac()
  if ac ~= current then
    current = ac
    apply_blur(ac)
  end
end, { timeout = 10000, type = "repeat" })
