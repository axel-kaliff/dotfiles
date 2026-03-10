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
            { desc = ' Tree', group = 'Oil', action = 'Oil --float', key = 'e' },
            { desc = '󰩈 Exit', group = 'ErrorMsg', action = 'q', key = 'q' },
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
      require('bufferline').setup {}
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
      local detail = false
      require('oil').setup {
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        watch_for_changes = true,
        view_options = {
          show_hidden = true,
        },
        float = {
          padding = 2,
          max_width = 120,
          max_height = 40,
        },
        keymaps = {
          -- Disable defaults that conflict with zellij-nav
          ['<C-h>'] = false,
          ['<C-l>'] = false,
          ['gd'] = {
            desc = 'Toggle file detail view',
            callback = function()
              detail = not detail
              if detail then
                require('oil').set_columns { 'icon', 'permissions', 'size', 'mtime' }
              else
                require('oil').set_columns { 'icon' }
              end
            end,
          },
          ['<leader>y'] = {
            desc = 'Yank filepath to clipboard',
            callback = function()
              require('oil.actions').copy_entry_path.callback()
              vim.fn.setreg('+', vim.fn.getreg(vim.v.register))
            end,
          },
        },
      }
      vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })

      -- Patch Oil SSH realpath to use POSIX-compatible syntax.
      -- Oil uses [[ which fails when the remote /bin/sh is dash.
      local SSHFS = require('oil.adapters.ssh.sshfs')
      SSHFS.realpath = function(self, path, callback)
        local cmd = string.format(
          'if ! readlink -f "%s" 2>/dev/null; then case "%s" in /*) echo "%s";; *) echo "$PWD/%s";; esac; fi',
          path,
          path,
          path,
          path
        )
        self.conn:run(cmd, function(err, lines)
          if err then
            return callback(err)
          end
          assert(lines)
          local abspath = table.concat(lines, '')
          if vim.endswith(abspath, '.') then
            abspath = abspath:sub(1, #abspath - 1)
          end
          local shellescape = function(s)
            return "'" .. s:gsub("'", "'\\''") .. "'"
          end
          self.conn:run(
            string.format('LC_ALL=C ls -land --color=never %s', shellescape(abspath)),
            function(ls_err, ls_lines)
              local type
              if ls_err then
                type = 'directory'
              else
                assert(ls_lines)
                local line = ls_lines[1]
                local typechar = line:sub(1, 1)
                local typemap = { l = 'link', d = 'directory', ['-'] = 'file' }
                type = typemap[typechar] or 'file'
              end
              if type == 'directory' then
                if not vim.endswith(abspath, '/') then
                  abspath = abspath .. '/'
                end
              end
              callback(nil, abspath)
            end
          )
        end)
      end
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

  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    opts = {},
  },
}
