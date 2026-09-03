-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Motion follows the material: Apple's default spring (SwiftUI
-- response 0.55 s, damping fraction 0.825, so stiffness 130 / damping 19 at
-- unit mass) for anything that arrives or moves, and a short accelerating
-- bezier for anything leaving. Workspace switching stays instant (the
-- Omarchy default).
hl.curve("appleSpring", { type = "spring", mass = 1, stiffness = 130, dampening = 19 })
hl.curve("appleExit", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 3, spring = "appleSpring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, spring = "appleSpring", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "appleExit", style = "popin 90%" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, spring = "appleSpring", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "appleExit", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, spring = "appleSpring", style = "slidefadevert 15%" })

-- Glass design language, after Apple's material stack (macOS vibrancy and
-- Liquid Glass). A surface is never a flat alpha wash: the backdrop is blurred
-- wide, re-saturated and slightly flattened so it stays legible; every surface
-- gets a 1px specular rim (bright at the top, a faint glint at the bottom)
-- instead of a coloured border; and a large soft shadow does the focus work
-- the accent border used to do. The shell half of this is omarchy/shell.toml.
--
-- Light themes flip the chrome the way macOS does: the hairline turns dark
-- (a white rim vanishes on a light backdrop), the backdrop is lifted rather
-- than dimmed, and the shadow gets lighter. `omarchy theme set` reloads
-- Hyprland, so the check re-runs on every theme switch.
local function theme_is_light()
  local marker = io.open((os.getenv("HOME") or "") .. "/.local/state/omarchy/current/theme/light.mode", "r")
  if marker then
    marker:close()
    return true
  end
  return false
end

local light = theme_is_light()
local rim_active = light
  and { colors = { "rgba(00000059)", "rgba(00000033)", "rgba(00000047)" }, angle = 90 }
  or { colors = { "rgba(ffffff80)", "rgba(ffffff1f)", "rgba(ffffff3d)" }, angle = 90 }
local rim_inactive = light and "rgba(00000024)" or "rgba(ffffff1f)"

hl.config({
  general = {
    gaps_in = 6,
    gaps_out = 14,
    border_size = 1,
    col = {
      active_border = rim_active,
      inactive_border = rim_inactive,
    },
  },

  group = {
    col = {
      border_active = rim_active,
      border_inactive = rim_inactive,
    },
  },

  decoration = {
    rounding = 14,
    -- Between a circle (2) and a squircle (4): Apple's continuous corners.
    rounding_power = 3.0,

    -- macOS window shadow, measured: ~22px drop, 45-70px blur, ~50% black on
    -- the active window; inactive windows keep a lighter one so they still
    -- sit on the desktop.
    shadow = {
      enabled = true,
      range = 56,
      render_power = 3,
      color = light and "rgba(00000059)" or "rgba(0000008c)",
      color_inactive = light and "rgba(0000002e)" or "rgba(00000047)",
      offset = { 0, 12 },
    },

    blur = {
      enabled = true,
      -- size * 2^passes is the effective radius: ~96px, the macOS 30pt
      -- quarter-resolution Gaussian at 2x.
      size = 12,
      passes = 3,
      -- Vibrancy re-saturates the blurred backdrop the way NSVisualEffectView
      -- does (~1.8x); contrast < 1 flattens luminosity the way Apple's
      -- regular material does; brightness < 1 is a post-blur dim.
      vibrancy = 0.28,
      vibrancy_darkness = 0.15,
      contrast = 0.88,
      brightness = light and 1.05 or 0.9,
      noise = 0.02,
      ignore_opacity = true,
      popups = true,
      popups_ignorealpha = 0.4,
    },
  },

  misc = {
    -- The lock screen is a session lock, not a layer: blur the desktop it
    -- covers instead of hiding it behind a flat wallpaper copy.
    session_lock_xray = true,
    session_lock_blur = true,
  },
})

-- Shell surfaces are layer-shell windows, so the compositor has to be told
-- which of them get the backdrop blur, and ignore_alpha decides which pixels
-- of a surface count. Cards that float on a QML drop shadow (toasts, OSD)
-- use a high threshold so only the card itself is blurred and the shadow
-- never rings; modal surfaces with a scrim (menu, clipboard, emojis, polkit)
-- use a low one so the whole desktop frosts behind them, macOS-style.
-- The bar never overlaps a window, so it samples the wallpaper only (xray):
-- the macOS under-window-background look, and cheaper.
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, blur_popups = true, xray = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "^(omarchy-notifications|omarchy-osd)$" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({
  match = {
    namespace = "^(omarchy-menu|omarchy-clipboard|omarchy-emojis|omarchy-polkit|omarchy-reminders"
      .. "|omarchy-keyboard-panel|omarchy-network-qr)$",
  },
  blur = true,
  ignore_alpha = 0.2,
})
-- Toasts enter from the screen edge like macOS notifications.
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, animation = "slide right" })
