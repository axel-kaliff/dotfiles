-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {

    {
      'nvimdev/dashboard-nvim',
      event = 'VimEnter',
      dependencies = { { 'nvim-tree/nvim-web-devicons' } },
      config = function()
        require('dashboard').setup {
          theme = 'hyper',
          config = {
            week_header = { enable = true },
            shortcut = {
              { desc = '󰊳 Update', group = '@property', action = 'Lazy update', key = 'u' },
              { icon = ' ', icon_hl = '@variable', desc = 'Files', group = 'Label', action = 'Telescope find_files', key = 'f' },
              { desc = ' Tree', group = 'Neotree', action = 'Neotree toggle left', key = 'e' },
              { desc = '󰩈 Exit', group = 'ErrorMsg', action = 'q', key = 'q' },
            },
          },
        }
      end,
    },



}
