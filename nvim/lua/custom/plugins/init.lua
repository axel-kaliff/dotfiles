local function is_centerpad_active()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if string.find(buf_name, 'leftpad') or string.find(buf_name, 'rightpad') then
      return true
    end
  end
  return false
end

return {

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
      { '<leader>cc', function() Snacks.zen() end, desc = 'Toggle Zen Mode' },
      { '<leader>gg', function() Snacks.lazygit() end, desc = 'Lazygit' },
      { '<leader>gl', function() Snacks.lazygit.log() end, desc = 'Lazygit Log' },
      { '<leader>tt', function() Snacks.terminal() end, desc = 'Toggle Terminal' },
      { '<leader>un', function() Snacks.notifier.show_history() end, desc = 'Notification History' },
    },
  },

  -- noice.nvim: modern UI for cmdline, messages, and popupmenu
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
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
    cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = 'Diffview Open' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = 'File History (current)' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<cr>', desc = 'File History (repo)' },
    },
    opts = {},
  },

  -- Bufferline
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup {
        options = {
          custom_filter = function(buf_number)
            local buf_name = vim.fn.bufname(buf_number)
            -- Filter out leftpad and rightpad buffers
            if buf_name:match 'leftpad' or buf_name:match 'rightpad' then
              return false
            end
            return true
          end,
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

  -- tmux nvim navigation
  -- {
  --   'aserowy/tmux.nvim',
  --   config = function()
  --     require('tmux').setup {}
  --   end,
  -- },

  {
    'https://github.com/swaits/zellij-nav.nvim',
    config = function()
      require('zellij-nav').setup()

      local map = vim.keymap.set
      -- map('n', '<c-h>', '<cmd>Centerpad<cr><cmd>ZellijNavigateLeftTab<cr><cmd>Centerpad<cr>', { desc = 'navigate left or tab' })
      map('n', '<c-j>', '<cmd>ZellijNavigateDown<cr>', { desc = 'navigate down' })
      map('n', '<c-k>', '<cmd>ZellijNavigateUp<cr>', { desc = 'navigate up' })
      -- this breaks navigation when centerpad is not on
      -- map('n', '<c-l>', '<cmd>Centerpad<cr><cmd>ZellijNavigateRightTab<cr><cmd>Centerpad<cr>', { desc = 'navigate right or tab' })
      --
      --
      map('n', '<c-h>', function()
        local was_active = is_centerpad_active()
        if was_active then
          vim.cmd 'Centerpad'
        end
        vim.cmd 'ZellijNavigateLeftTab'
        if was_active then
          vim.cmd 'Centerpad'
        end
      end, { desc = 'navigate left or tab' })

      map('n', '<c-l>', function()
        local was_active = is_centerpad_active()
        if was_active then
          vim.cmd 'Centerpad'
        end
        vim.cmd 'ZellijNavigateRightTab'
        if was_active then
          vim.cmd 'Centerpad'
        end
      end, { desc = 'navigate right or tab' })
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

  { 'EdenEast/nightfox.nvim' },

  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
  },

  { 'smithbm2316/centerpad.nvim' },

  {
    'MagicDuck/grug-far.nvim',
    opts = {},
    keys = {
      { '<leader>sR', function() require('grug-far').open() end, desc = 'Search and Replace (grug-far)' },
    },
  },

  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    ft = { 'markdown' },
    opts = {},
  },
}
