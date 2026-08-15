-- Poll-refresh Neogit: its own watcher only sees .git/, so edits made by
-- another process (e.g. Claude Code in the ide layout) never trigger it.
-- Only the ide zellij layout calls start(); normal Neogit use is untouched.
-- start() being called is therefore the only marker that this nvim IS that
-- pane, which <leader>gn reads to keep Neogit full-width there.
local M = { is_ide_pane = false }

function M.start()
  M.is_ide_pane = true

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
