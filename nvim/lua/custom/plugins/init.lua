return {

  -- Dashboard handled by snacks.nvim (see below)

  -- fzf-lua: replaces telescope with native fzf performance
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VimEnter',
    config = function()
      local fzf = require 'fzf-lua'
      fzf.setup {
        'default-title',
        fzf_colors = true,
        winopts = {
          preview = { default = 'bat' },
        },
      }

      -- Register as the UI select handler (replaces telescope-ui-select)
      fzf.register_ui_select()

      local map = vim.keymap.set
      map('n', '<leader>sh', fzf.helptags, { desc = '[S]earch [H]elp' })
      map('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
      map('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
      map('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect Picker' })
      map({ 'n', 'v' }, '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
      map('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
      map('n', '<leader>sd', fzf.diagnostics_workspace, { desc = '[S]earch [D]iagnostics' })
      map('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
      map('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      map('n', '<leader>sc', fzf.commands, { desc = '[S]earch [C]ommands' })
      map('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })
      map('n', '<leader>/', fzf.grep_curbuf, { desc = '[/] Fuzzily search in current buffer' })
      map('n', '<leader>s/', function()
        fzf.live_grep { grep_open_buffers = true }
      end, { desc = '[S]earch [/] in Open Files' })
      map('n', '<leader>sn', function()
        fzf.files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
      map('n', '<leader>st', '<cmd>TodoFzfLua<cr>', { desc = '[S]earch [T]odo comments' })
    end,
  },

  -- snacks.nvim: modular QoL features (dashboard, zen, indent, notifier, etc.)
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = {
        enabled = true,
        sections = {
          { section = 'header' },
          { icon = ' ', title = 'Keymaps', section = 'keys', indent = 2, padding = 1 },
          { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
          { icon = ' ', title = 'Projects', section = 'projects', indent = 2, padding = 1 },
          { section = 'startup' },
        },
      },
      indent = { enabled = true },
      notifier = { enabled = true },
      scroll = { enabled = true },
      bigfile = { enabled = true },
      words = { enabled = true },
      zen = {
        enabled = true,
        toggles = { dim = true },
        win = { width = 90 },
      },
      lazygit = { enabled = true },
      terminal = { enabled = true },
    },
    keys = {
      { '<leader>tz', function() Snacks.zen() end, desc = 'Toggle Zen Mode' },
      { '<leader>gg', function() Snacks.lazygit() end, desc = 'Lazygit' },
      { '<leader>gl', function() Snacks.lazygit.log() end, desc = 'Lazygit Log' },
      { '<leader>tt', function() Snacks.terminal() end, desc = 'Toggle Terminal' },
      { '<leader>un', function() Snacks.notifier.show_history() end, desc = 'Notification History' },
      { '<leader>uN', function() Snacks.notifier.hide() end, desc = 'Dismiss Notifications' },
      { ']w', function() Snacks.words.jump(1) end, desc = 'Next word reference' },
      { '[w', function() Snacks.words.jump(-1) end, desc = 'Previous word reference' },
    },
  },

  -- noice.nvim: modern UI for cmdline, messages, and popupmenu
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>um', '<cmd>Noice history<cr>', desc = 'Message History (Noice)' },
      { '<leader>ud', '<cmd>Noice dismiss<cr>', desc = 'Dismiss Messages (Noice)' },
      {
        '<c-d>',
        function()
          if not require('noice.lsp').scroll(4) then
            return vim.fn.mode() == 'n' and '<c-d>zz' or '<c-d>'
          end
        end,
        silent = true,
        expr = true,
        desc = 'Scroll down and center',
        mode = { 'n', 'i', 's' },
      },
      {
        '<c-u>',
        function()
          if not require('noice.lsp').scroll(-4) then
            return vim.fn.mode() == 'n' and '<c-u>zz' or '<c-u>'
          end
        end,
        silent = true,
        expr = true,
        desc = 'Scroll up and center',
        mode = { 'n', 'i', 's' },
      },
    },
    opts = {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          ['cmp.entry.get_documentation'] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    },
  },

  -- neogit: magit-style git interface
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'ibhagwan/fzf-lua',
    },
    cmd = 'Neogit',
    opts = {
      integrations = {
        fzf_lua = true,
        diffview = true,
      },
    },
    keys = {
      { '<leader>gn', '<cmd>Neogit<cr>', desc = 'Neogit' },
      { '<leader>gc', '<cmd>Neogit commit<cr>', desc = 'Neogit Commit' },
      { '<leader>gp', '<cmd>Neogit push<cr>', desc = 'Neogit Push' },
    },
  },

  -- diffview.nvim: tabpage diff review and merge conflict resolution
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory', 'DiffviewClose' },
    keys = {
      {
        '<leader>gd',
        function()
          local lib = require 'diffview.lib'
          if lib.get_current_view() then
            vim.cmd.DiffviewClose()
          else
            vim.cmd.DiffviewOpen()
          end
        end,
        desc = 'Diffview Toggle',
      },
      { '<leader>gq', '<cmd>DiffviewClose<cr>', desc = 'Diffview Close' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'File History (current)' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'File History (repo)' },
    },
    opts = {
      keymaps = {
        view = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
        },
        file_panel = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
        },
        file_history_panel = {
          { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
        },
      },
    },
  },

  -- Bufferline
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup {
        options = {
          diagnostics = 'nvim_lsp',
          show_close_icon = false,
          show_buffer_close_icons = false,
          separator_style = 'thin',
          offsets = {
            { filetype = 'oil', text = 'File Explorer', highlight = 'Directory' },
          },
        },
      }
    end,
  },

  {
    'https://github.com/swaits/zellij-nav.nvim',
    config = function()
      require('zellij-nav').setup()

      -- Wrap navigation to skip command-line window (q:) where wincmd is invalid
      local function zellij_nav(cmd)
        return function()
          if vim.fn.getcmdwintype() ~= '' then return end
          vim.cmd(cmd)
        end
      end

      local map = vim.keymap.set
      map('n', '<c-h>', zellij_nav('ZellijNavigateLeftTab'), { desc = 'navigate left or tab' })
      map('n', '<c-j>', zellij_nav('ZellijNavigateDown'), { desc = 'navigate down' })
      map('n', '<c-k>', zellij_nav('ZellijNavigateUp'), { desc = 'navigate up' })
      map('n', '<c-l>', zellij_nav('ZellijNavigateRightTab'), { desc = 'navigate right or tab' })
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
    'EdenEast/nightfox.nvim',
    priority = 1000,
    lazy = false,
    config = function()
      require('nightfox').setup {}
      vim.cmd.colorscheme 'terafox'
    end,
  },

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
    event = 'BufReadPre',
    opts = {},
    keys = {
      { '<leader>qs', function() require('persistence').load() end, desc = 'Load session (current dir)' },
      { '<leader>qS', function() require('persistence').select() end, desc = 'Select and load session' },
      { '<leader>ql', function() require('persistence').load { last = true } end, desc = 'Load last session' },
      { '<leader>qd', function() require('persistence').stop() end, desc = 'Stop session auto-save' },
    },
  },

  {
    'stevearc/oil.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'refractalize/oil-git-status.nvim',
    },
    config = function()
      local detail = false
      require('oil').setup {
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        watch_for_changes = true,
        lsp_file_methods = {
          autosave_changes = true,
        },
        win_options = {
          signcolumn = 'yes:2',
        },
        view_options = {
          show_hidden = true,
        },
        keymaps = {
          -- Disable defaults that conflict with zellij-nav
          ['<C-h>'] = false,
          ['<C-l>'] = false,
          ['<C-v>'] = { 'actions.select', opts = { vertical = true }, desc = 'Open in vsplit' },
          ['<C-x>'] = { 'actions.select', opts = { horizontal = true }, desc = 'Open in split' },
          ['q'] = 'actions.close',
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
      require('oil-git-status').setup()
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
      { '<leader>sR', function() require('grug-far').open() end, desc = 'Search and Replace (grug-far)' },
      {
        '<leader>sR',
        function()
          require('grug-far').open { prefills = { search = vim.fn.expand '<cword>' }, visualSelectionUsed = true }
        end,
        mode = 'v',
        desc = 'Search and Replace selection (grug-far)',
      },
    },
  },

  -- Treesitter textobjects: select/move/swap functions, classes, parameters
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = 'VeryLazy',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ['af'] = { query = '@function.outer', desc = 'Select around function' },
            ['if'] = { query = '@function.inner', desc = 'Select inside function' },
            ['ac'] = { query = '@class.outer', desc = 'Select around class' },
            ['ic'] = { query = '@class.inner', desc = 'Select inside class' },
            ['aa'] = { query = '@parameter.outer', desc = 'Select around argument' },
            ['ia'] = { query = '@parameter.inner', desc = 'Select inside argument' },
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']m'] = { query = '@function.outer', desc = 'Next function start' },
            [']]'] = { query = '@class.outer', desc = 'Next class start' },
          },
          goto_next_end = {
            [']M'] = { query = '@function.outer', desc = 'Next function end' },
            [']['] = { query = '@class.outer', desc = 'Next class end' },
          },
          goto_previous_start = {
            ['[m'] = { query = '@function.outer', desc = 'Previous function start' },
            ['[['] = { query = '@class.outer', desc = 'Previous class start' },
          },
          goto_previous_end = {
            ['[M'] = { query = '@function.outer', desc = 'Previous function end' },
            ['[]'] = { query = '@class.outer', desc = 'Previous class end' },
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ['<leader>a'] = { query = '@parameter.inner', desc = 'Swap with next argument' },
          },
          swap_previous = {
            ['<leader>A'] = { query = '@parameter.inner', desc = 'Swap with previous argument' },
          },
        },
      }
    end,
  },

  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    opts = {},
  },
}
