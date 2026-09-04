-- What leaves the machine and what may read the screen.

-- Shell surfaces that carry private text stay out of shared screens:
-- notifications (message previews) and the clipboard history. Hyprland paints
-- nothing where they are in the screencopy stream.
hl.layer_rule({
  match = { namespace = "^(omarchy-notifications|omarchy-clipboard)$" },
  no_screen_share = true,
})

-- Hold off the idle lock while a screen share is running, so a long call or
-- a presentation never locks the screen mid-sentence. Only sessions that last
-- longer than a screenshot count, and a stay-awake the user set by hand is
-- left alone when the share ends.
local stay_awake_flag = (os.getenv("HOME") or "") .. "/.local/state/omarchy/indicators/stay-awake"

local function stay_awake_set()
  local flag = io.open(stay_awake_flag, "r")
  if flag then
    flag:close()
    return true
  end
  return false
end

local held_awake = false
local hold_timer = nil

hl.on("screenshare.state", function(active)
  if active then
    if hold_timer then
      hold_timer:set_enabled(false)
    end
    hold_timer = hl.timer(function()
      if not held_awake and not stay_awake_set() then
        held_awake = true
        hl.exec_cmd("omarchy-toggle-idle stay-awake")
      end
    end, { timeout = 2000, type = "oneshot" })
    return
  end

  if hold_timer then
    hold_timer:set_enabled(false)
    hold_timer = nil
  end
  if held_awake then
    held_awake = false
    hl.exec_cmd("omarchy-toggle-idle allow-idle")
  end
end)

-- macOS-style screen capture permissions: the tools the desktop itself uses
-- are allowed, anything else gets a prompt the first time it asks for the
-- screen. Takes effect on the next Hyprland start (permissions are not
-- hot-reloaded).
hl.config({ ecosystem = { enforce_permissions = true } })
hl.permission({
  binary = "^/usr/bin/(grim|hyprpicker|gpu-screen-recorder|quickshell|qs)$",
  type = "screencopy",
  mode = "allow",
})
hl.permission({
  binary = "^/usr/libexec/xdg-desktop-portal-hyprland$",
  type = "screencopy",
  mode = "allow",
})
