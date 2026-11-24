-- bonfire Neovim colors: ember orange and blood red on black. Applied on top of any colorscheme.
local C = { black = "#080808", panel = "#1a0d08", ember = "#ff8700", orange = "#ff5f1f", red = "#ff4500",
            blood = "#e60000", gold = "#ffaa00", ash = "#5a4a42", text = "#e8dccb" }
local M = {}
function M.apply()
  local set = function(g, o) vim.api.nvim_set_hl(0, g, o) end
  set("LineNr", { fg = C.orange }); set("CursorLineNr", { fg = C.red, bold = true })
  set("WinSeparator", { fg = C.red, bg = "none" }); set("NvimTreeWinSeparator", { fg = C.red, bg = "none" })
  for _, g in ipairs({ "NvimTreeFolderName", "NvimTreeOpenedFolderName", "NvimTreeRootFolder" }) do set(g, { fg = C.red, bold = true }) end
  set("NvimTreeFolderIcon", { fg = C.red }); set("NvimTreeIndentMarker", { fg = C.red }); set("NvimTreeEmptyFolderName", { fg = C.orange })
  set("NvimTreeNormal", { fg = C.orange, bg = "none" }); set("NvimTreeNormalNC", { fg = C.orange, bg = "none" })
  set("NvimTreeFileIcon", { fg = C.orange }); set("NvimTreeExecFile", { fg = C.orange, bold = true }); set("NvimTreeOpenedFile", { fg = C.gold, bold = true })
  set("NvimTreeSpecialFile", { fg = C.red, underline = true }); set("NvimTreeImageFile", { fg = C.orange })
  set("NvimTreeGitDirty", { fg = C.gold }); set("NvimTreeGitNew", { fg = C.orange }); set("NvimTreeGitDeleted", { fg = C.blood })
  set("DevIconLua", { fg = C.orange }); set("DevIconJson", { fg = C.gold }); set("DevIconDefault", { fg = C.orange })
  set("DashboardHeader", { fg = C.red, bold = true }); set("AlphaButtons", { fg = C.orange }); set("AlphaShortcut", { fg = C.blood, bold = true })
end
local b = { fg = C.ember, bg = C.panel }; local c = { fg = C.text, bg = "none" }
M.lualine = {
  normal = { a = { fg = C.black, bg = C.ember, gui = "bold" }, b = b, c = c },
  insert = { a = { fg = C.black, bg = C.gold, gui = "bold" }, b = b, c = c },
  visual = { a = { fg = C.black, bg = C.red, gui = "bold" }, b = b, c = c },
  replace = { a = { fg = C.black, bg = C.blood, gui = "bold" }, b = b, c = c },
  command = { a = { fg = C.black, bg = C.orange, gui = "bold" }, b = b, c = c },
  inactive = { a = { fg = C.ash, bg = "none" }, b = { fg = C.ash, bg = "none" }, c = { fg = C.ash, bg = "none" } },
}
return M
