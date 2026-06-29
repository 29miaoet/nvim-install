-- Set a line number
vim.opt.number = true

-- Show commands when typing
vim.opt.showcmd = true

-- ALways use lf line endings
vim.opt.fileformat = "unix"

-- Set tab length to 4 spaces, and convert tabs into spaces
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Create a group so autocommands don't duplicate
local tab_adjustments = vim.api.nvim_create_augroup("TabAdjustments", { clear = true })

-- Web Development (2 spaces), soft tab
vim.api.nvim_create_autocmd("FileType", {
  group = tab_adjustments,
  pattern = { "html", "css", "javascript", "typescript", "javascriptreact", "typescriptreact" },
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

-- C / C++ (8 spaces), hard tab
vim.api.nvim_create_autocmd("FileType", {
  group = tab_adjustments,
  pattern = { "c", "cpp" },
  callback = function()
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
    vim.bo.softtabstop = 8
    vim.bo.expandtab = true
  end,
})

-- Map jj to close insert mode
vim.keymap.set('i', 'jj', '<Esc>', { noremap = true })

-- Restore last cursor position when opening a file
local cursor_group = vim.api.nvim_create_augroup('remember_cursor', { clear = true })

vim.api.nvim_create_autocmd('BufReadPost', {
  group = cursor_group,
  callback = function()
    local line = vim.fn.line('\'"')
    if line > 0 and line <= vim.fn.line('$') then
      vim.cmd('normal! g`"')
    end
  end,
})

-- Visual tweaks
vim.cmd("highlight Normal guibg=NONE")
vim.api.nvim_set_hl(0, 'LineNr', { fg = '#FFFF00' })
vim.api.nvim_set_hl(0, 'NonText', { fg = '#0000FF' })
vim.opt.termguicolors = true

-- Bootstrap Lazy and enable plugins
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup("plugins", {
  rocks = {
    enabled = false,
  },
})

-- reduce visual noise
vim.opt.fillchars = { eob = " " }

-- Easy method for commenting multiple lines in python
vim.keymap.set("v", "<leader>/", ":s/^/#/<CR>", {
  desc = "Comment selected lines"
})

-- Use bash as Neovim's shell
vim.opt.shell = vim.env.SHELL or "/bin/bash"

