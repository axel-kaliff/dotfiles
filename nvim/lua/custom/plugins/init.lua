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
            { icon = ' ', icon_hl = '@variable', desc = 'Files', group = 'Label', action = 'Telescope find_files', key = 'f' },
            { desc = ' Tree', group = 'Neotree', action = 'Neotree toggle left', key = 'e' },
            { desc = '󰩈 Exit', group = 'ErrorMsg', action = 'q', key = 'q' },
          },
        },
      }
    end,
  },

  -- Neotree
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    lazy = false,
    config = function()
      require('neo-tree').setup {
        close_if_last_window = true,
        popup_border_style = 'rounded',
        enable_git_status = true,
        enable_diagnostics = false,
        source_selector = {
          winbar = false,
        },

        default_component_configs = {
          indent = {
            indent_size = 1,
            padding = 1, -- extra padding on left hand side
            with_markers = true,
            indent_marker = '│',
            last_indent_marker = '└',
            highlight = 'NeoTreeIndentMarker',
          },
          icon = {
            folder_closed = '',
            folder_open = '',
            default = '',
          },
        },
        filesystem = {
          use_libuv_file_watcher = true,
          filtered_items = {
            show_hidden = true,
            respect_gitignore = true,
          },
          window = {
            position = 'float',
            mappings = {
              f = 'none',
            },
          },
        },
      }
    end,
  },

  {
    's1n7ax/nvim-window-picker',
    version = '2.*',
    config = function()
      require('window-picker').setup {
        filter_rules = {
          include_current_win = false,
          autoselect_one = true,
          -- filter using buffer options
          bo = {
            -- if the file type is one of following, the window will be ignored
            filetype = { 'neo-tree', 'neo-tree-popup', 'notify' },
            -- if the buffer type is one of following, the window will be ignored
            buftype = { 'terminal', 'quickfix' },
          },
        },
      }
    end,
  },

  -- Bufferline
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup {
        options = {
          offsets = {
            {
              filetype = 'neo-tree',
              text = 'File Explorer',
              highlight = 'Directory',
              separator = true,
            },
          },
        },
      }
    end,
  },

  {
    'https://github.com/swaits/zellij-nav.nvim',
    config = function()
      require('zellij-nav').setup()

      local map = vim.keymap.set
      map('n', '<c-h>', '<cmd>ZellijNavigateLeftTab<cr>', { desc = 'navigate left or tab' })
      map('n', '<c-j>', '<cmd>ZellijNavigateDown<cr>', { desc = 'navigate down' })
      map('n', '<c-k>', '<cmd>ZellijNavigateUp<cr>', { desc = 'navigate up' })
      map('n', '<c-l>', '<cmd>ZellijNavigateRightTab<cr>', { desc = 'navigate right or tab' })
    end,
  },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },
      { 'S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
    },
  },

  { 'EdenEast/nightfox.nvim' },

  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
    cmd = 'Trouble',
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
      { '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' },
      { '<leader>xL', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List (Trouble)' },
      { '<leader>xQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' },
    },
  },

  {
    'folke/persistence.nvim',
    event = 'BufReadPre', -- this will only start session saving when an actual file was opened
    opts = {
      -- add any custom options here
    },
  },

  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('oil').setup {
        view_options = {
          show_hidden = true,
        },
      }
      vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })
    end,
  },

  {
    'MagicDuck/grug-far.nvim',
    opts = {},
    keys = {
      { '<leader>sr', function() require('grug-far').open() end, desc = 'Search and Replace (grug-far)' },
    },
  },

  {
    'folke/zen-mode.nvim',
    opts = {
      window = { width = 90 },
    },
    keys = {
      { '<leader>cc', '<cmd>ZenMode<cr>', desc = 'Toggle Zen Mode' },
    },
  },
}
