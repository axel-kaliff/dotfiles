-- Poll-refresh Neogit: its own watcher only sees .git/, so edits made by
-- another process (e.g. Claude Code in the ide layout) never trigger it.
-- Only the ide zellij layout calls start(); normal Neogit use is untouched.
local M = {}

function M.start()
  local timer = vim.uv.new_timer()
  timer:start(
    2000,
    2000,
    vim.schedule_wrap(function()
      require('neogit').dispatch_refresh()
    end)
  )
end

return M
