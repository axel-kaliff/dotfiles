-- Global key mappings

-- Shortcut for lazygit in a floating terminal
vim.keymap.set('n', '<leader>gl', '<cmd>FloatermNew lazygit<cr>', { desc = '[G]it [L]azy' })


vim.keymap.set('n', '<C-n>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Buffer Cycle Next' })
vim.keymap.set('n', '<C-b>d', '<cmd>bdelete<cr>', { desc = 'Buffer Close' })

-- Toggle file tree (Neotree)
vim.keymap.set('n', '<leader>t', '<cmd>Neotree toggle position=left<cr>', { desc = '[F]ile tree [T]oggle' })

-- Telescope keymaps
vim.keymap.set('n', '<leader>?', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>/', function()
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })
vim.keymap.set('n', '<leader>s/', function()
  require('telescope.builtin').live_grep { grep_open_files = true, prompt_title = 'Live Grep in Open Files' }
end, { desc = '[S]earch [/] in Open Files' })
vim.keymap.set('n', '<leader>ss', require('telescope.builtin').builtin, { desc = '[S]elect Telescope' })
vim.keymap.set('n', '<leader>gf', require('telescope.builtin').git_files, { desc = 'Search [G]it [F]iles' })
vim.keymap.set('n', '<leader>sf', require('telescope.builtin').find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sG', ':LiveGrepGitRoot<cr>', { desc = '[S]earch by [G]rep on Git Root' })
vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', require('telescope.builtin').resume, { desc = '[S]earch [R]esume' })
