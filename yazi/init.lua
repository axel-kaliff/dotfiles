-- Required for the git fetcher registered in yazi.toml: setup() initializes the
-- plugin's shared state; without it every fetch errors and the task never finishes.
require("git"):setup()

-- Record every directory visited (any tab, any instance) in zoxide's db,
-- so `Z` fzf-searches the full cross-session directory history.
require("zoxide"):setup({ update_db = true })

-- Session persistence lives in plugins/tab-session.yazi (no setup needed):
-- hypr/bin/yazi-session emits `plugin tab-session` after launch, which
-- restores the saved tabs and arms continuous autosave in that instance.
