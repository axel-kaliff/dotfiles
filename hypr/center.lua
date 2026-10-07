-- Center mode: scrolling centers the focused column, including a lone column;
-- dwindle shows the focused tiled window alone in a scroll-column-width band.
--
-- Dwindle cannot center one tile. Maximizing leaves its tree untouched, so
-- turning the mode off restores the exact layout. The f[1] workspace rules
-- confine the band to maximized windows, leaving scrolling workspaces unsqueezed.
-- Omarchy's misc.on_focus_under_fullscreen = 1 transfers the maximized slot on
-- focus; binds.movefocus_cycles_fullscreen = true lets SUPER+H/L cycle it.
-- The mode is kept in a flag file, so it survives reloads and restarts.
-- A reload starts a fresh Lua state, so the mode cannot live in a global.

local flag = require("default.hypr.paths").state_home .. "/omarchy/toggles/center-mode"
local function flag_set()
  local file = io.open(flag)
  if file then file:close() end
  return file ~= nil
end
local on = flag_set()

local band_rules = {}
-- Read before applying: reload resets options before running the config again.
local fit = hl.get_config("scrolling.focus_fit_method")
local one_column = hl.get_config("scrolling.fullscreen_on_one_column")

local function add_band(monitor)
  local width = monitor.width / monitor.scale
  local gaps = hl.get_config("general.gaps_out")
  local band = hl.get_config("scrolling.column_width") * (width - gaps.left - gaps.right)
  local side = math.floor((width - band) / 2)
  table.insert(band_rules, hl.workspace_rule({
    workspace = "m[" .. monitor.name .. "]f[1]",
    gaps_out = { top = gaps.top, right = side, bottom = gaps.bottom, left = side },
  }))
end

local function band(window)
  if not on or not window or window.floating then return end
  local workspace = window.workspace
  if not workspace or workspace.tiled_layout ~= "dwindle" or workspace.has_fullscreen then return end
  hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = window }))
end

local function apply()
  hl.config({ scrolling = { focus_fit_method = 0, fullscreen_on_one_column = false } })
  for _, monitor in ipairs(hl.get_monitors()) do add_band(monitor) end
end

if on then apply() end
hl.on("window.active", band)
hl.on("monitor.added", function(monitor) if on then add_band(monitor) end end)

local function toggle()
  on = not on
  if on then
    local file = assert(io.open(flag, "w")); file:close()
    apply()
    local window = hl.get_active_window()
    if window and window.workspace and window.workspace.tiled_layout == "scrolling" then
      hl.dispatch(hl.dsp.layout("center"))
    end
    band(window)
  else
    os.remove(flag)
    hl.config({ scrolling = { focus_fit_method = fit, fullscreen_on_one_column = one_column } })
    for _, rule in ipairs(band_rules) do rule:set_enabled(false) end
    band_rules = {}
    for _, window in ipairs(hl.get_windows()) do
      if window.fullscreen == 1 and window.workspace and window.workspace.tiled_layout == "dwindle" then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = window }))
      end
    end
  end
  hl.exec_cmd("omarchy-notification-send -g 󰡌 'Center mode " .. (on and "on" or "off") .. "'")
end

o.bind("SUPER + ALT + C", "Center mode", toggle)
