-- Scratchpads: named special workspaces that launch their own app.
--
-- `on_created_empty` runs the command the first time the special workspace is
-- summoned, and Hyprland destroys a special workspace once its last window
-- closes (misc.close_special_on_empty), so the next toggle spawns the app
-- again. No launcher script and no window bookkeeping; the window rule only
-- makes sure a fresh instance lands in the pad rather than on the workspace
-- that happened to be focused.

-- Music. The stock Music key runs omarchy-launch-spotify, which looks for
-- /usr/bin/spotify and otherwise opens the Arch installer; on pneuma Spotify
-- is the flatpak.
hl.workspace_rule({
  workspace = "special:music",
  on_created_empty = "uwsm-app -- flatpak run com.spotify.Client",
})
o.window("(?i).*spotify.*", { workspace = "special:music silent" })

hl.unbind("SUPER + SHIFT + M") -- was: Music (omarchy-launch-spotify)
o.bind("SUPER + SHIFT + M", "Music", hl.dsp.workspace.toggle_special("music"))

-- Four fingers down pulls the music pad over the desktop; the existing
-- four-finger horizontal swipe keeps switching workspaces.
hl.gesture({ fingers = 4, direction = "down", action = "special", workspace_name = "music" })
