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

-- Motion follows the material: Apple's default spring shape (damping
-- fraction 0.825) at twice Apple's pace, response 0.275 s instead of
-- 0.55 s, for anything that arrives or moves, and a short accelerating
-- bezier for anything leaving. Springs are simulated on real time and
-- ignore `speed`, so their pace lives in the constants: doubling the
-- natural frequency (stiffness x4, damping x2 at unit mass) halves every
-- timing while keeping the same bounce. Workspace switching stays instant
-- (the Omarchy default).
hl.curve("appleSpring", { type = "spring", mass = 1, stiffness = 520, dampening = 38 })
hl.curve("appleExit", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
-- Three times appleSpring's pace, same bounce (stiffness x9, damping x3): for
-- windowsMove, which is what slides the scrolling tape when focus moves.
hl.curve("appleSpringFast", { type = "spring", mass = 1, stiffness = 4680, dampening = 114 })

hl.animation({ leaf = "windows", enabled = true, speed = 1.5, spring = "appleSpring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, spring = "appleSpring", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 0.75, bezier = "appleExit", style = "popin 90%" })
-- windowsMove has no scroll-only sibling, so dwindle moves and resizes speed up too.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, spring = "appleSpringFast" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.5, spring = "appleSpring", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 0.75, bezier = "appleExit", style = "fade" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.5, spring = "appleSpring", style = "slidefadevert 15%" })

-- The leaves Omarchy's default looknfeel sets (border colour, window and
-- layer fades) at half its speeds, so nothing lags behind the springs.
hl.animation({ leaf = "border", enabled = true, speed = 2.7, bezier = "easeOutQuint" })
-- The shadow colour switch lives on its own leaf (fadeShadow, a child of
-- fade). Animating it flickers: the fade damages a region smaller than the
-- shadow covers, so the cached blur framebuffer serves stale pixels for the
-- rest. Forcing a full repaint (debug:damage_tracking 0) or dropping the blur
-- cache (blur:new_optimizations) hides it equally well and both cost far more
-- than the fade is worth; the shadow's colour, range, offset and falloff make
-- no difference to it. So the shadow snaps while the rim keeps border's fade.
hl.animation({ leaf = "fadeShadow", enabled = false })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 0.85, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 0.75, bezier = "almostLinear" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.9, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 0.9, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.7, bezier = "almostLinear" })

-- Glass design language, after Apple's material stack (macOS vibrancy and
-- Liquid Glass). A surface is never a flat alpha wash: the backdrop is blurred
-- wide, re-saturated and slightly flattened so it stays legible; every surface
-- gets a 1px specular rim (brighter along the top edge)
-- instead of a coloured border; and a large soft shadow does the focus work
-- the accent border used to do. The shell half of this is omarchy/shell.toml.
--
-- Light themes flip the chrome the way macOS does: the hairline turns dark
-- (a white rim vanishes on a light backdrop), the backdrop is lifted rather
-- than dimmed, and the shadow gets lighter. `omarchy theme set` reloads
-- Hyprland, so the check re-runs on every theme switch. omarchy-theme-color
-- resolves the mode the way the shell does: the `mode` key in colors.toml
-- first (what every stock light theme sets), then a light.mode marker, then
-- background luminance.
local light = o.shell_succeeds('[ "$(omarchy-theme-color mode)" = light ]')

-- Hyprland's own chrome -- group tabs, the not-responding dialog -- in the
-- same serif as the Omarchy shell (~/.config/fontconfig/conf.d).
local font = "Geist Serif"
local rim_active = light
  and { colors = { "rgba(00000059)", "rgba(00000033)" }, angle = 90 }
  or { colors = { "rgba(ffffff73)", "rgba(ffffff26)" }, angle = 90 }
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
    -- Floating windows snap to screen edges and to each other while dragged.
    snap = { enabled = true },
  },

  group = {
    -- Dropping a floating window onto a stack's tabs adds it to the stack.
    -- Off by default, and the only mouse gesture that puts a floating window
    -- into an existing stack -- the rest of grouping already assumes tiles.
    merge_floated_into_tiled_on_groupbar = true,

    col = {
      border_active = rim_active,
      border_inactive = rim_inactive,
    },

    -- Group tabs in the same material as the bar's pills: a blurred strip
    -- with rounded, translucent tab fills instead of Omarchy's flat black
    -- washes. The active tab is the selected-pill tint (0.18 white, 0.16
    -- black on light themes); inactive tabs barely register until hovered.
    groupbar = {
      blur = true,
      font_family = font,
      gradients = true,
      gradient_rounding = 8,
      gradient_rounding_power = 3.0,
      rounding = 8,
      indicator_height = 0,
      text_color = light and "rgb(000000)" or "rgb(ffffff)",
      text_color_inactive = light and "rgba(00000099)" or "rgba(ffffff99)",
      col = {
        active = light and "rgba(00000029)" or "rgba(ffffff2e)",
        inactive = light and "rgba(0000000f)" or "rgba(ffffff12)",
      },
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
      -- Scratchpads (named special workspaces) hover over a frosted desktop,
      -- the same treatment the menu and clipboard get.
      special = true,
      -- Dual Kawase: each pass halves resolution and samples `size` px out,
      -- so the reach is 2 * size * (2^passes - 1) = 168px, a wide, soft
      -- frost in the range of macOS's 30pt Gaussian at quarter resolution.
      size = 12,
      passes = 3,
      -- Vibrancy re-saturates the blurred backdrop the way NSVisualEffectView
      -- does (~1.8x); contrast < 1 flattens luminosity the way Apple's
      -- regular material does; brightness < 1 is a post-blur dim.
      vibrancy = 0.28,
      vibrancy_darkness = 0.3,
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
    font_family = font,
  },

  cursor = {
    -- The pointer already hides while typing (Omarchy default); also hide it
    -- once the hand leaves the mouse, the way macOS does.
    inactive_timeout = 3,
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
hl.layer_rule({ match = { namespace = "^(omarchy-notifications|omarchy-osd|pneuma-switcher)$" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({
  match = {
    namespace = "^(omarchy-menu|omarchy-clipboard|omarchy-emojis|omarchy-polkit|omarchy-reminders"
      .. "|omarchy-keyboard-panel|omarchy-network-qr)$",
  },
  blur = true,
  ignore_alpha = 0.2,
})
-- The overview's own swipe drives every pixel of its appearance, so the
-- compositor's layer fade would only fight it: the grid would be fading in
-- while the fingers are already placing it.
hl.layer_rule({ match = { namespace = "pneuma-overview" }, no_anim = true })

-- Toasts enter from the screen edge like macOS notifications.
hl.layer_rule({ match = { namespace = "omarchy-notifications" }, animation = "slide right" })

-- Liquid Glass after cosmic-forge's shader (verified 2026-10-28):
-- https://github.com/motixo/cosmic-forge-shaders/blob/main/shaders/liquid-glass.frag
-- hyprglass v0.11.0 is pinned upstream to Hyprland 0.56.2; it builds against
-- 0.56.1's headers because the only plugin-visible header change is one added
-- non-virtual renderer method, leaving layout unchanged. The optics approximate
-- that shader's defaults: mostly sharp backdrop, strong inward edge lens,
-- about 5px of dispersion, no tint or centre dome. Hyprglass's 50px refraction
-- cap weakens the lens versus cosmic-forge's pull of up to 40% of the pane inward.
-- Tone copies the frost above so glassed windows match blurred shell surfaces;
-- globals beat per-theme tone because theme slots default to sentinels (PluginConfig.cpp).
-- Glass sits under the window and needs translucent backgrounds to show: A/B
-- screenshots found it invisible at Ghostty background-opacity 0.92, subtle at 0.75, clear at 0.5.
-- The .so is built against this exact Hyprland and stays machine-local, outside
-- the repo, because these dotfiles also serve a host without it. hl.plugin.load
-- is declarative, so it must run on every config pass to keep the plugin loaded;
-- the config API exists only on the pass after the load.
local hyprglass_path = os.getenv("HOME") .. "/.local/lib/hyprland/hyprglass.so"
local hyprglass_file = io.open(hyprglass_path, "r")
if hyprglass_file then
  hyprglass_file:close()
  hl.permission({ binary = (hyprglass_path:gsub("%.", "\\.")), type = "plugin", mode = "allow" })
  hl.plugin.load(hyprglass_path)
  if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    hg.config({
      default_theme = light and "light" or "dark",
      blur_strength = 0.5,
      blur_iterations = 2,
      refraction_strength = 1.0,
      edge_thickness = 0.1,
      lens_distortion = 0.0,
      chromatic_aberration = 0.3,
      fresnel_strength = 0.4,
      specular_strength = 0.6,
      tint_color = 0x00000000,
      brightness = light and 1.05 or 0.9,
      contrast = 0.88,
      saturation = 1.0,
      vibrancy = 0.28,
      vibrancy_darkness = 0.3,
      adaptive_dim = 0.0,
      adaptive_boost = 0.0,
      layers = { enabled = true },
    })

    -- The bar's flat, unrounded full-width strip is 0.62 alpha: glass covers it
    -- all and the lens follows its edges; 0.5 matches its blur cutoff.
    -- Full-screen layers draw rounded cards (0.66-0.9 alpha) over a 0.35 scrim
    -- or nothing; toasts are 0.66. Toasts, OSD and switcher have soft black
    -- shadows at <=0.3, so 0.5 keeps them out. Contour gives each card its own
    -- edge, lens and highlights instead of the screen rectangle; 0.5 excludes
    -- the 0.35 scrims but keeps every card. Polkit needs 0.7 to exclude its
    -- 0.5 scrim under an ~0.86 card. pneuma-dock exists only in easy mode.
    -- omarchy-network-qr stays unglassed: no translucent card, only an opaque
    -- QR code on a 0.78 scrim.
    -- omarchy-keyboard-panel hosts the bar's dropdowns (clock, power, network,
    -- ...); pneuma-window-menu is the right-click window menu. Glassed layers
    -- replace Hyprland blur (layers.manage_blur defaults on), so their
    -- ignore_alpha rules above only matter without the plugin. The bar's xdg
    -- popups (tooltips, tray and media cards) never get plugin glass and keep
    -- blur_popups.
    hg.layer("omarchy-bar", { mask_threshold = 0.5 })
    for _, ns in ipairs({
      "omarchy-menu",
      "omarchy-clipboard",
      "omarchy-emojis",
      "omarchy-reminders",
      "omarchy-keyboard-panel",
      "pneuma-window-menu",
      "omarchy-notifications",
      "omarchy-osd",
      "pneuma-switcher",
      "pneuma-dock",
    }) do
      hg.layer(ns, { mask_mode = "contour", mask_threshold = 0.5 })
    end
    hg.layer("omarchy-polkit", { mask_mode = "contour", mask_threshold = 0.7 })
  end
end
