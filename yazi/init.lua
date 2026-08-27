-- Required for the git fetcher registered in yazi.toml: setup() initializes the
-- plugin's shared state; without it every fetch errors and the task never finishes.
require("git"):setup()

-- Record every directory visited (any tab, any instance) in zoxide's db,
-- so `Z` fzf-searches the full cross-session directory history.
require("zoxide"):setup({ update_db = true })

-- Tabs auto-save as the "last" project on quit; hypr/bin/yazi-session
-- restores it on launch (load_after_start would clobber `yazi <dir>`).
require("projects"):setup({
	save = { method = "lua" },
	last = { update_before_quit = true },
	notify = { enable = false },
})
