-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })

-- Pneuma default: US + Swedish layouts, toggle with SUPER + SHIFT + SPACE
-- (see bindings.lua). No grp:* toggle here on purpose: every grp option that
-- uses Alt (grp:alts_toggle and friends) rebinds <RALT> to plain Alt_R, which
-- destroys AltGr/ISO_Level3_Shift -- and with it @ $ { [ ] } \ | ~ on "se".
hl.config({
  input = {
    kb_layout = "us,se",
    kb_options = "compose:caps,shift:both_capslock_cancel,altwin:swap_lalt_lwin",
  },
})

-- Navigate workspaces by swiping horizontally with either three or four fingers.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Mission Control: swipe up with three or four fingers for the window
-- overview, down with three to put it back (omarchy/plugins/pneuma.overview).
--
-- These forward raw finger travel and nothing else. Whether the overview is
-- up is the shell's to know, so a `hyprctl reload` -- which wipes everything
-- these closures hold -- cannot leave the two halves disagreeing about what
-- is on screen, and Escape or a click can close it without telling Hyprland.
local function overview_swipe(direction, sign)
  local travel = 0
  local announced = 0

  local function announce(message)
    hl.dispatch(hl.dsp.event("overview>>" .. message))
  end

  return {
    start = function()
      travel = 0
      announced = 0
      announce("start:" .. direction)
    end,
    -- A touchpad reports motion far finer than the overview can show, so
    -- only a step worth redrawing is worth waking the shell for.
    update = function(event)
      travel = travel + sign * event.delta.y
      if math.abs(travel - announced) < 6 then return end
      announced = travel
      announce("move:" .. math.floor(travel))
    end,
    finish = function(event)
      announce("end:" .. (event.cancelled and "1" or "0"))
    end,
  }
end

hl.gesture({ fingers = 3, direction = "up", action = overview_swipe("up", -1) })
hl.gesture({ fingers = 4, direction = "up", action = overview_swipe("up", -1) })
hl.gesture({ fingers = 3, direction = "down", action = overview_swipe("down", 1) })
