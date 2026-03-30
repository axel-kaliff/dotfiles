-- Leader key (must be set before plugins load)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

-- [[ Options ]]
vim.o.number = true
vim.o.relativenumber = true

vim.o.mouse = 'a'
vim.o.showmode = false

-- Clipboard: sync with OS, force OSC 52 in Zellij
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'

  -- Zellij: force OSC 52 (zellij-org/zellij#3951)
  if vim.env.ZELLIJ then
    vim.g.clipboard = {
      name = 'OSC 52',
      copy = {
        ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
        ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
      },
      paste = {
        ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
        ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
      },
    }
  end
end)

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true

-- [[ Keymaps ]]

vim.keymap.set('n', '<S-l>', '<cmd>BufferLineCycleNext<cr>', { desc = 'Buffer Cycle Next' })
vim.keymap.set('n', '<S-h>', '<cmd>BufferLineCyclePrev<cr>', { desc = 'Buffer Cycle Previous' })

vim.keymap.set('n', 'gb', '<cmd>BufferLinePick<cr>', { desc = 'Pick Buffer' })
vim.keymap.set('n', '<leader>bd', '<cmd>bp|bd #<cr>', { desc = 'Buffer Close' })
vim.keymap.set('n', '<leader>bo', '<cmd>BufferLineCloseOthers<cr>', { desc = 'Buffer Close Others' })
vim.keymap.set('n', '<leader>bl', '<cmd>BufferLineCloseLeft<cr>', { desc = 'Buffer Close Left' })
vim.keymap.set('n', '<leader>br', '<cmd>BufferLineCloseRight<cr>', { desc = 'Buffer Close Right' })

vim.keymap.set('n', '<leader>e', '<cmd>Oil<cr>', { desc = 'File explorer (Oil)' })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Move lines up/down
vim.keymap.set('n', '<A-j>', '<cmd>move .+1<cr>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', '<cmd>move .-2<cr>==', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":move '>+1<cr>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":move '<-2<cr>gv=gv", { desc = 'Move selection up' })

-- Better indenting — keeps visual selection
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right' })

-- Paste over selection without yanking the replaced text
vim.keymap.set('x', 'p', '"_dP', { desc = 'Paste without losing register' })

-- Window splits
vim.keymap.set('n', '<leader>w-', '<cmd>split<cr>', { desc = 'Split horizontal' })
vim.keymap.set('n', '<leader>w|', '<cmd>vsplit<cr>', { desc = 'Split vertical' })
vim.keymap.set('n', '<leader>wd', '<cmd>close<cr>', { desc = 'Close split' })

-- Quickfix navigation
vim.keymap.set('n', ']q', '<cmd>cnext<cr>zz', { desc = 'Next quickfix' })
vim.keymap.set('n', '[q', '<cmd>cprev<cr>zz', { desc = 'Previous quickfix' })
vim.keymap.set('n', ']l', '<cmd>lnext<cr>zz', { desc = 'Next loclist' })
vim.keymap.set('n', '[l', '<cmd>lprev<cr>zz', { desc = 'Previous loclist' })

-- Diagnostic navigation
vim.keymap.set('n', ']d', function() vim.diagnostic.jump { count = 1 } end, { desc = 'Next diagnostic' })
vim.keymap.set('n', '[d', function() vim.diagnostic.jump { count = -1 } end, { desc = 'Previous diagnostic' })
vim.keymap.set('n', ']e', function() vim.diagnostic.jump { count = 1, severity = vim.diagnostic.severity.ERROR } end, { desc = 'Next error' })
vim.keymap.set('n', '[e', function() vim.diagnostic.jump { count = -1, severity = vim.diagnostic.severity.ERROR } end, { desc = 'Previous error' })

-- SESSION MANAGEMENT
vim.keymap.set('n', '<leader>qs', function()
  require('persistence').load()
end, { desc = 'Load session (current dir)' })

vim.keymap.set('n', '<leader>qS', function()
  require('persistence').select()
end, { desc = 'Select and load session' })

vim.keymap.set('n', '<leader>ql', function()
  require('persistence').load { last = true }
end, { desc = 'Load last session' })

vim.keymap.set('n', '<leader>qd', function()
  require('persistence').stop()
end, { desc = 'Stop session auto-save' })

-- Terminal escape
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Save
vim.keymap.set('n', '<C-s>', '<cmd>w<cr>', { desc = 'Write buffer to file' })
vim.keymap.set('i', '<C-s>', '<cmd>w<cr>', { desc = 'Write buffer to file' })

-- Toggles
vim.keymap.set('n', '<leader>tn', function()
  vim.o.relativenumber = not vim.o.relativenumber
end, { desc = '[T]oggle relative line [N]umbers' })

vim.keymap.set('n', '<leader>td', function()
  local current = vim.diagnostic.config()
  if current.virtual_text then
    vim.diagnostic.config { virtual_text = false }
  else
    vim.diagnostic.config { virtual_text = { source = 'if_many', spacing = 2 } }
  end
end, { desc = '[T]oggle [D]iagnostic virtual text' })

-- Lazy plugin manager
vim.keymap.set('n', '<leader>ul', '<cmd>Lazy<cr>', { desc = 'Lazy Plugin Manager' })

-- Undo tree (built-in in nvim 0.12)
vim.keymap.set('n', '<leader>uu', '<cmd>Undotree<cr>', { desc = 'Undo Tree' })

-- CTRL+<hjkl> navigation is handled by zellij-nav.nvim plugin
-- (navigates both neovim splits and zellij panes)

-- [[ Autocommands ]]
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ lazy.nvim bootstrap ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Plugins ]]
require('lazy').setup({
  'NMAC427/guess-indent.nvim',

  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>g', group = '[G]it' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>x', group = 'Diagnostics' },
        { '<leader>u', group = '[U]I' },
        { '<leader>q', group = 'Session' },
        { '<leader>b', group = '[B]uffer' },
        { '<leader>w', group = '[W]indow' },
        { '<leader>d', group = '[D]ebug' },
        { 'gr', group = 'LSP (Go to / Refactor)' },
        { 's', desc = 'Flash', mode = { 'n', 'x', 'o' } },
        { '-', desc = 'File Explorer (Oil)' },
      },
    },
  },

  -- LSP: Lua development support
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      'saghen/blink.cmp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          local fzf = require 'fzf-lua'
          map('grr', fzf.lsp_references, '[G]oto [R]eferences')
          map('gri', fzf.lsp_implementations, '[G]oto [I]mplementation')
          map('grd', fzf.lsp_definitions, '[G]oto [D]efinition')
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('gO', fzf.lsp_document_symbols, 'Open Document Symbols')
          map('gW', fzf.lsp_live_workspace_symbols, 'Open Workspace Symbols')
          map('grt', fzf.lsp_typedefs, '[G]oto [T]ype Definition')

          -- Highlight references under cursor
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
        },
      }

      local capabilities = require('blink.cmp').get_lsp_capabilities()
      local servers = {
        gopls = {},
        ts_ls = {},
        rust_analyzer = {},
        ruff = {},
        pyright = {
          settings = {
            pyright = {
              disableOrganizeImports = true, -- Ruff handles imports
            },
            python = {
              analysis = {
                ignore = { '*' }, -- Ruff handles linting
              },
            },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              completion = { callSnippet = 'Replace' },
            },
          },
        },
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {},
        automatic_installation = false,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'ruff_format' },
        fish = { 'fish_indent' },
      },
    },
  },

  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          {
            'rafamadriz/friendly-snippets',
            config = function()
              require('luasnip.loaders.from_vscode').lazy_load()
            end,
          },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
      signature = { enabled = true },
    },
  },

  -- Secondary colorscheme — available via :colorscheme tokyonight-* but not loaded at startup
  {
    'folke/tokyonight.nvim',
    lazy = true,
    opts = {
      styles = {
        comments = { italic = false },
      },
    },
  },

  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup()
      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      local filetypes = {
        'bash', 'c', 'diff', 'dockerfile', 'fish', 'go', 'html', 'javascript',
        'json', 'kdl', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'python',
        'query', 'rust', 'toml', 'typescript', 'vim', 'vimdoc', 'yaml',
      }
      local to_install = vim.tbl_filter(function(ft)
        local ok = pcall(vim.treesitter.language.inspect, ft)
        return not ok
      end, filetypes)
      if #to_install > 0 then
        require('nvim-treesitter').install(to_install)
      end
      vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function()
          vim.treesitter.start()
        end,
      })
    end,
  },

  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.lint',
  require 'kickstart.plugins.autopairs',
  require 'kickstart.plugins.gitsigns',

  { import = 'custom.plugins' },
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- Prevent padding buffers from taking over when closing a buffer
vim.api.nvim_create_autocmd('BufDelete', {
  callback = function()
    vim.schedule(function()
      local current_buf_name = vim.fn.bufname()
      if current_buf_name == 'leftpad' or current_buf_name == 'rightpad' then
        -- Find the first valid, listed buffer
        local bufs = vim.api.nvim_list_bufs()
        for _, buf_id in ipairs(bufs) do
          local buf_name = vim.fn.bufname(buf_id)
          if vim.api.nvim_buf_is_valid(buf_id) and vim.bo[buf_id].buflisted and buf_name ~= 'leftpad' and buf_name ~= 'rightpad' then
            vim.api.nvim_set_current_buf(buf_id)
            return
          end
        end
      end
    end)
  end,
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
