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
            use_libuv_file_watcher = true,
            filtered_items = {
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
        local dap = require('dap')

        -- dap.adapters.python = {
        --   type = 'executable';
        --   command = os.getenv('HOME') .. '/.virtualenvs/tools/bin/python';
        --   args = { '-m', 'debugpy.adapter' };
        -- }

        -- dap.configurations.python = {
        --   {
        --     type = 'python',
        --     request = 'launch',
        --     name = "Launch file",
        --     program = "${file}",
        --     pythonPath = function()
        --       return '/workspaces/'
        --     end,
        --   },
        -- }


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

        require('dap-python').setup("uv")
      end,
    },


    { "EdenEast/nightfox.nvim" },

}

