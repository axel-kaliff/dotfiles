# COSMIC todo

What the Hyprland setup does that this COSMIC port cannot yet, checked against COSMIC 1.8.0
(Fedora 44) on 2026-09-24. Each item names the upstream change to watch for and what to do once
it lands. Test every change in the VM first (`just vm run`).

## Waiting on COSMIC

- [ ] **Three-finger gestures and swipe-up overview.**
  Hyprland: 3 and 4 fingers sideways switch workspace, 3 and 4 fingers up open the overview
  (`hypr/input.lua`). cosmic-comp 1.8 acts only on 4-finger sideways swipes; 3 fingers is a
  `// TODO: 3 finger gestures` in `src/input/mod.rs`, and there is no gesture config.
  Watch: gesture settings in cosmic-comp or cosmic-settings.
  Then: map the same gestures. Interim option, not taken: a libinput daemon, which needs the
  `input` group and so can read every keystroke.

- [ ] **Blur behind Ghostty.**
  cosmic-comp 1.8 blurs only through `ext-background-effect-v1`; Ghostty 1.3 speaks only KDE's
  `org_kde_kwin_blur`. Translucent Ghostty windows show the wallpaper unblurred.
  Watch: Ghostty supporting `ext-background-effect`, or cosmic-comp adding the KDE protocol.
  Then: `background-blur = true` in `ghostty/config`.

- [ ] **Night light.**
  Hyprland used hyprsunset (`hypr/hyprsunset.conf`). cosmic-settings has a night-light page
  that is still commented out on master, and cosmic-comp has no gamma control protocol.
  Watch: the night-light page being enabled, or `wlr-gamma-control` in cosmic-comp.
  Then: port the hyprsunset schedule.

- [ ] **Bar font.**
  The Omarchy bar is set in the system monospace (Noto Sans Mono). COSMIC has one interface font
  for the panel and every COSMIC app, so setting it would make Files and Settings monospace too.
  Watch: a panel-only font setting.

- [ ] **Hide windows from screen shares.**
  Hyprland kept Bitwarden, notifications and the clipboard out of screencasts
  (`hypr/privacy.lua`, Omarchy's `no_screen_share` rules). cosmic-comp has no per-window
  exclusion.
  Watch: a window rule or capture-source filter in cosmic-comp.

- [ ] **Window menu on Super+right-click.**
  COSMIC shortcuts take no mouse buttons.
  Watch: mouse bindings in `com.system76.CosmicSettings.Shortcuts`.

- [ ] **Focus the urgent window (Super+U).**
  No shortcut action exists, and the toplevel-info protocol reports no urgent state for a window.
  Watch: an urgent state in `zcosmic_toplevel_handle_v1`.
  Then: `pneuma-wm focus-urgent`, bound to Super+U.

- [ ] **Floating window size.**
  Omarchy floats its tagged windows at 875x600, centred. COSMIC tiling exceptions only float;
  the app picks its own size.
  Watch: size or position in the window rules.
  Then: add sizes to `config/com.system76.CosmicSettings.WindowRules/v1/tiling_exception_custom`.

## Workarounds to delete once COSMIC fixes the cause

- [ ] **Relayout message.**
  An applet whose bar content grows renders clipped, because the runtime requests the surface
  size before the view is rebuilt. Weather, app-name, media and workspaces send themselves a
  no-op `Message::Relayout` to force a second pass.
  Watch: libcosmic's autosize requesting the size after `view`.
  Then: remove the `Relayout` variants.

- [ ] **Clipboard picker as a separate daemon.**
  An applet popup opened from a shortcut gets no keyboard focus, and an applet cannot open a
  layer surface. So the picker runs as `pneuma-clipboard-picker` with its own user unit, and the
  bar button only calls its D-Bus `Toggle`.
  Watch: keyboard focus for applet popups opened by a message.
  Then: fold the picker back into the applet and drop the unit.

## Possible today, not done yet

- [ ] **Easy mode leaves existing workspaces tiled.**
  `autotile` only applies to workspaces created after it changes. The cosmic workspace protocol
  (v2) has `set_tiling_state`, so `pneuma-easy-mode` could untile every existing workspace, and
  tile them again on the way out.
- [ ] **Urgent workspace on Super+U.**
  ext-workspace does report `Urgent` per workspace, so Super+U could at least switch to the
  urgent workspace until the window-level state exists.
- [ ] **Pomodoro popup keyboard shortcuts.**
  The Omarchy widget's popup took keys; the applet's popup is mouse only.
