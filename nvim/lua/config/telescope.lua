-- Telescope configuration
require('telescope').setup {
  defaults = {
    mappings = {
      i = { ['<C-u>'] = false, ['<C-d>'] = false },
    },
  },
}
pcall(require('telescope').load_extension, 'fzf')

-- Create a command to live grep in the current Git root
local function find_git_root()
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = (current_file == '') and vim.fn.getcwd() or vim.fn.fnamemodify(current_file, ':h')
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.escape(current_dir, ' ') .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    print 'Not a git repository. Using current working directory.'
    return vim.fn.getcwd()
  end
  return git_root
end

local function live_grep_git_root()
  local git_root = find_git_root()
  if git_root then
    require('telescope.builtin').live_grep { search_dirs = { git_root } }
  end
end

vim.api.nvim_create_user_command('LiveGrepGitRoot', live_grep_git_root, {})
