-- Loads terminal-realms colors in Neovim. Installed into ~/.config/nvim/plugin/ by install.sh.
local home = vim.env.REALM_HOME or (vim.fn.expand("~") .. "/.config/terminal-realms")
if vim.fn.isdirectory(home .. "/nvim") == 0 or vim.g.terminal_realms_disable then return end
vim.opt.runtimepath:append(home .. "/nvim")
require("terminal_realms").setup(vim.g.terminal_realms or {})
