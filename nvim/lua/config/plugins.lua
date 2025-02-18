-- lua/config/plugins.lua

-- Bootstrap lazy.nvim if needed
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin configuration using lazy.nvim
require('lazy').setup({
    -- Basic plugins
    { 'echasnovski/mini.nvim', version = false },
    'tpope/vim-fugitive',
    'tpope/vim-rhubarb',
    'tpope/vim-sleuth',

    -- LSP and related plugins
    {
      'neovim/nvim-lspconfig',
      dependencies = {
        { 'williamboman/mason.nvim', config = true },
        'williamboman/mason-lspconfig.nvim',
        { 'j-hui/fidget.nvim',       opts = {} },
        'folke/neodev.nvim',
      },
    },

    -- Autocompletion plugins
    {
      'hrsh7th/nvim-cmp',
      dependencies = {
        {
          'L3MON4D3/LuaSnip',
          build = (function()
            if vim.fn.has('win32') == 1 then return end
            return 'make install_jsregexp'
          end)(),
        },
        'saadparwaiz1/cmp_luasnip',
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-path',
        'rafamadriz/friendly-snippets',
      },
    },

    -- null-ls for formatting/diagnostics
    {
      "jose-elias-alvarez/null-ls.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        local null_ls = require("null-ls")
        null_ls.setup({
          sources = {
            null_ls.builtins.diagnostics.ruff,
            null_ls.builtins.formatting.ruff,
          }
        })
      end
    },

    -- Other useful plugins
    { 'folke/which-key.nvim',  opts = {} },
    {
      'lewis6991/gitsigns.nvim',
      opts = {
        signs = {
          add          = { text = '+' },
          change       = { text = '~' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end
          map({ 'n', 'v' }, ']c', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gs.next_hunk() end)
            return '<Ignore>'
          end, { expr = true, desc = 'Jump to next hunk' })
          map({ 'n', 'v' }, '[c', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gs.prev_hunk() end)
            return '<Ignore>'
          end, { expr = true, desc = 'Jump to previous hunk' })
          map('v', '<leader>hs', function() gs.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
            { desc = 'Stage git hunk' })
          map('v', '<leader>hr', function() gs.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
            { desc = 'Reset git hunk' })
          map('n', '<leader>hs', gs.stage_hunk, { desc = 'Stage git hunk' })
          map('n', '<leader>hr', gs.reset_hunk, { desc = 'Reset git hunk' })
          map('n', '<leader>hS', gs.stage_buffer, { desc = 'Stage buffer' })
          map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Undo stage hunk' })
          map('n', '<leader>hR', gs.reset_buffer, { desc = 'Reset buffer' })
          map('n', '<leader>hp', gs.preview_hunk, { desc = 'Preview hunk' })
          map('n', '<leader>hb', function() gs.blame_line { full = false } end, { desc = 'Blame line' })
          map('n', '<leader>hd', gs.diffthis, { desc = 'Diff against index' })
          map('n', '<leader>hD', function() gs.diffthis '~' end, { desc = 'Diff against last commit' })
          map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = 'Toggle blame line' })
          map('n', '<leader>td', gs.toggle_deleted, { desc = 'Show deleted' })
          map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Select hunk' })
        end,
      },
    },

    -- Dashboard
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
              { desc = ' Tree', group = 'Neotree', action = 'Neotree toggle left', key = 't' },
              { desc = '󰩈 Exit', group = 'ErrorMsg', action = 'q', key = 'q' },
            },
          },
        }
      end,
    },

    { "NoahTheDuke/vim-just",   ft = { "just" } },
    { "EdenEast/nightfox.nvim" },
    { "meatballs/notebook.nvim" },
    {
      'nvim-lualine/lualine.nvim',
      opts = {
        options = {
          icons_enabled = false,
          theme = 'auto',
          component_separators = '|',
          section_separators = '',
        },
        -- tabline = {
        --   lualine_a = { 'buffers' },
        --   lualine_b = {},
        --   lualine_c = {},
        --   lualine_x = {},
        --   lualine_y = {},
        --   lualine_z = { 'tabs' }
        -- },
        -- sections = {
        --   -- these are to remove the defaults
        --   lualine_a = {},
        --   lualine_b = {},
        --   lualine_y = {},
        --   lualine_z = {},
        --   -- These will be filled later
        --   lualine_c = {},
        --   lualine_x = {},
        -- },

      },
    },
    {
      'lukas-reineke/indent-blankline.nvim',
      main = 'ibl',
      opts = {},
    },
    -- Neotree
    {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
      },
      config = function()
        require('neo-tree').setup({
          close_if_last_window = true,
          -- popup_border_style = 'rounded',
          enable_git_status = true,
          enable_diagnostics = true,
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
              folder_closed = '',
              folder_open = '',
              default = '',
            },
          },
          filesystem = {
            follow_current_file = true,
            use_libuv_file_watcher = true,
            filters = {
              show_hidden = true,
              respect_gitignore = true,
            },
            window = {
              position = 'left',
              mappings = {
                f = 'none',
              },
            },
          },
        })
      end,
    },

    -- Bufferline
    {
      'akinsho/bufferline.nvim',
      version = "*",
      dependencies = 'nvim-tree/nvim-web-devicons',
      config = function()

      end,
    },

    { 'numToStr/Comment.nvim', opts = {} },
    {
      'nvim-telescope/telescope.nvim',
      branch = '0.1.x',
      dependencies = {
        'nvim-lua/plenary.nvim',
        {
          'nvim-telescope/telescope-fzf-native.nvim',
          build = 'make',
          cond = function() return vim.fn.executable('make') == 1 end,
        },
      },
    },
    {
      'nvim-treesitter/nvim-treesitter',
      dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
      build = ':TSUpdate',
    },
    { 'dense-analysis/ale' },
    { 'averms/black-nvim' },
    { 'voldikss/vim-floaterm' },

    ----------------------------------------------------------------------------
    -- Debugger configuration: nvim-dap and related plugins
    ----------------------------------------------------------------------------
    {
      'mfussenegger/nvim-dap',
      dependencies = {
        'rcarriga/nvim-dap-ui',
        'nvim-neotest/nvim-nio',
        'williamboman/mason.nvim',
        'jay-babu/mason-nvim-dap.nvim',
        'mfussenegger/nvim-dap-python',
      },
      keys = {
        {
          '<F5>',
          function() require('dap').continue() end,
          desc = 'Debug: Start/Continue',
        },
        {
          '<F1>',
          function() require('dap').step_into() end,
          desc = 'Debug: Step Into',
        },
        {
          '<F2>',
          function() require('dap').step_over() end,
          desc = 'Debug: Step Over',
        },
        {
          '<F3>',
          function() require('dap').step_out() end,
          desc = 'Debug: Step Out',
        },
        {
          '<leader>b',
          function() require('dap').toggle_breakpoint() end,
          desc = 'Debug: Toggle Breakpoint',
        },
        {
          '<leader>B',
          function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end,
          desc = 'Debug: Set Breakpoint',
        },
        {
          '<F7>',
          function() require('dapui').toggle() end,
          desc = 'Debug: See last session result.',
        },
      },
      config = function()
        local dap   = require('dap')
        local dapui = require('dapui')

        require('mason-nvim-dap').setup {
          automatic_installation = true,
          handlers = {},
          ensure_installed = { 'delve' },
        }

        dapui.setup {
          icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
          controls = {
            icons = {
              pause      = '⏸',
              play       = '▶',
              step_into  = '⏎',
              step_over  = '⏭',
              step_out   = '⏮',
              step_back  = 'b',
              run_last   = '▶▶',
              terminate  = '⏹',
              disconnect = '⏏',
            },
          },
        }

        dap.listeners.after.event_initialized['dapui_config'] = dapui.open
        dap.listeners.before.event_terminated['dapui_config'] = dapui.close
        dap.listeners.before.event_exited['dapui_config']     = dapui.close

        require('dap-python').setup("/usr/local/bin/python")
      end,
    },
  }
  ,
  {})

require("bufferline").setup({
  options = {
    offsets = {
      {
        filetype = "neo-tree",
        text = "File Explorer",
        highlight = "Directory",
        separator = true
      }
    },
    -- numbers = function(opts)
    --   return string.format('%s·', opts.ordinal)
    -- end,
  }
})
