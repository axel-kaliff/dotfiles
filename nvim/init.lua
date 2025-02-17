-- Set <space> as the leader key
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load configuration modules
require('config.options')
require('config.plugins')
require('config.keymaps')
require('config.autocmds')
require('config.telescope')
require('config.treesitter')
require('config.lsp')
require('config.cmp')
require('config.whichkey')
require('config.dashboard')
require('config.debug')

-- Modeline
-- vim: ts=2 sts=2 sw=2 et
