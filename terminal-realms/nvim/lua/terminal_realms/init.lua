-- terminal_realms: Neovim side of terminal-realms.
--   require("terminal_realms").setup()            colors for the window's realm (done for you by the plugin file)
--   require("terminal_realms").alpha(dashboard)   realm art, quote and menu colors for alpha-nvim's dashboard theme;
--                                                 call it right before alpha.setup(dashboard.opts)
local M = {}
local home = vim.env.REALM_HOME or (vim.fn.expand("~") .. "/.config/terminal-realms")

local function default_realm()
  local f = io.open(home .. "/current", "r")
  if not f then return "bonfire" end
  local s = f:read("*l"); f:close()
  return (s and s ~= "") and s or "bonfire"
end
M.name = vim.env.REALM or default_realm()
M.dir = home .. "/realms/" .. M.name

local function load(file)
  local path = M.dir .. "/" .. file
  if vim.fn.filereadable(path) == 0 then return nil end
  local ok, mod = pcall(dofile, path)
  return ok and mod or nil
end

-- clear backgrounds so the terminal's realm color shows through
local function transparent()
  for _, g in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "EndOfBuffer", "StatusLine", "StatusLineNC",
                       "NvimTreeNormal", "NvimTreeNormalNC", "TabLine", "TabLineFill" }) do
    vim.api.nvim_set_hl(0, g, { bg = "none", fg = vim.api.nvim_get_hl(0, { name = g }).fg })
  end
end

function M.setup(opts)
  opts = opts or {}
  local colors = load("nvim.lua")
  local function apply()
    if opts.transparent ~= false then transparent() end
    if colors then colors.apply() end
  end
  vim.api.nvim_create_autocmd("ColorScheme", { callback = function() vim.schedule(apply) end })
  vim.api.nvim_create_autocmd({ "VimEnter", "User" }, {
    pattern = { "*", "VeryLazy" },
    callback = function()
      vim.schedule(apply)
      if colors and colors.lualine and opts.lualine ~= false then
        vim.defer_fn(function()
          local ok, lualine = pcall(require, "lualine")
          if not ok or not lualine.get_config then return end
          local cfg = lualine.get_config(); cfg.options = cfg.options or {}; cfg.options.theme = colors.lualine
          pcall(lualine.setup, cfg)
        end, 150)
      end
    end,
  })
  apply()
end

function M.alpha(dashboard)
  local art = load("dashboard.lua")
  if not art then return end
  local s = dashboard.section
  s.header.val = art.lines; s.header.opts.hl = art.hl
  if art.quote then
    local same = vim.env.REALM_QUOTE_REALM == nil or vim.env.REALM_QUOTE_REALM == M.name
    local q = (same and vim.env.REALM_QUOTE and vim.env.REALM_QUOTE ~= "") and vim.env.REALM_QUOTE or art.quote()
    local mark = art.quote_mark or "*"
    s.footer.val = mark .. " " .. q .. " " .. mark
    s.footer.opts.hl = "AlphaQuote"; s.footer.opts.position = "center"
  end
  if vim.g.terminal_realms_credit ~= false then
    local credit = { type = "text", val = "terminal-realms · by WizSeb", opts = { hl = "AlphaCredit", position = "center" } }
    table.insert(dashboard.opts.layout, credit)
    vim.api.nvim_set_hl(0, "AlphaCredit", { link = "Comment", default = true })
  end
  -- short windows (like a Zellij pane): small art, three buttons, tight spacing
  local room = vim.o.lines - vim.o.cmdheight - 3
  local need = #art.lines + #s.buttons.val * 2 + 6
  if room < need and art.small_lines then
    s.header.val = art.small_lines; s.header.opts.hl = art.small_hl
    local keep = {}
    for _, b in ipairs(s.buttons.val) do
      local sc = b.opts and b.opts.shortcut or ""
      if sc == "e" or sc:find("ff") or sc == "q" then table.insert(keep, b) end
    end
    if #keep > 0 then s.buttons.val = keep end
    s.buttons.opts.spacing = 0
    local l = dashboard.opts.layout
    if l[1] and l[1].type == "padding" then l[1].val = 0 end
    if l[3] and l[3].type == "padding" then l[3].val = 1 end
  end
  for _, b in ipairs(s.buttons.val) do
    b.opts.hl = b.opts.hl or "AlphaMenuDescription"; b.opts.hl_shortcut = b.opts.hl_shortcut or "AlphaMenuShortcut"
  end
  art.setup()
end

return M
