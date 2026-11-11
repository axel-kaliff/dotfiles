-- What leaves the machine and what may read the screen.

-- Keep clipboard history out of shared screens and silence notifications below.
-- Omarchy 4.5 keeps their layer mapped, so blanking it would leave a black strip
-- in every share.
hl.layer_rule({
  match = { namespace = "^omarchy-clipboard$" },
  no_screen_share = true,
})

-- Release only DND enabled here; the runtime flag survives reloads, not reboots.
local dnd_hold = [[sh -c '[ "$(omarchy-shell notifications isDnd)" = off ] && omarchy-shell notifications setDnd on >/dev/null && touch "$XDG_RUNTIME_DIR/omarchy-share-dnd"']]
local dnd_release = [[sh -c 'rm "$XDG_RUNTIME_DIR/omarchy-share-dnd" 2>/dev/null && omarchy-shell notifications setDnd off >/dev/null']]

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
    hl.exec_cmd(dnd_hold)
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

  hl.exec_cmd(dnd_release)
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
