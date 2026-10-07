-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- The obsidian-work vault is always open (hyprland.lua places it on workspace 7).
-- Opening it by URI focuses the vault's window if Obsidian already restored it.
o.launch_on_start('flatpak run md.obsidian.Obsidian "obsidian://open?vault=obsidian-work"')
