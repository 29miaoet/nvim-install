-- Disable unneeded providers
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- Set a line number
vim.opt.number = true

-- Show commands when typing
vim.opt.showcmd = true

-- Automatically choose the appropriate line endings
vim.opt.fileformats = { "unix", "dos", "mac" }

-- Set tab length to 4 spaces, and convert tabs into spaces
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Create a group so autocommands don't duplicate
local tab_adjustments =
  vim.api.nvim_create_augroup("TabAdjustments", { clear = true })

-- Web Development (2 spaces), soft tab
vim.api.nvim_create_autocmd("FileType", {
  group = tab_adjustments,
  pattern = {
    "html",
    "css",
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
    "lua",
    "ruby",
    "yml",
    "yaml",
    "xml",
    "json",
  },
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

-- Map jj to close insert mode
vim.keymap.set("i", "jj", "<Esc>", { noremap = true })

-- Restore last cursor position when opening a file
local cursor_group =
  vim.api.nvim_create_augroup("remember_cursor", { clear = true })

vim.api.nvim_create_autocmd("BufReadPost", {
  group = cursor_group,
  callback = function()
    local line = vim.fn.line("'\"")

    if line > 0 and line <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end,
})

-- Visual tweaks
vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
vim.api.nvim_set_hl(0, "LineNr", { fg = "#FFFF00" })
vim.api.nvim_set_hl(0, "NonText", { fg = "#0000FF" })
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

-- Reduce visual noise
vim.opt.fillchars = { eob = " " }

-- Easy method for commenting multiple lines in Python
vim.keymap.set("v", "<leader>/", ":s/^/#/<CR>", {
  desc = "Comment selected lines",
})

-- Use the user's normal Linux shell.
--
-- Neovim already defaults to the user's shell on Unix systems, but
-- explicitly selecting it makes the behavior predictable.
local user_shell = vim.env.SHELL

if user_shell and vim.fn.executable(user_shell) == 1 then
  vim.opt.shell = user_shell
else
  vim.opt.shell = "bash"
end

vim.opt.shellcmdflag = "-c"
vim.opt.shellquote = ""
vim.opt.shellxquote = ""

-- Run a command in a vertical terminal split.
local function run_in_terminal(cmd)
  vim.cmd("rightbelow vsplit")

  local terminal_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, terminal_buf)

  vim.fn.termopen(cmd, {
    buffer = terminal_buf,
  })

  vim.cmd("startinsert")
end

-- IntelliSense for Python and TypeScript
--
-- TypeScript 7's native language server is provided by:
--
--     tsc --lsp --stdio
--
-- Keep this invocation rather than using the older
-- typescript-language-server wrapper.
vim.lsp.config("ts_ls", {
  cmd = { "tsc", "--lsp", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

vim.lsp.config("basedpyright", {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = {
    "python",
  },
})

-- Enable IntelliSense
vim.lsp.enable("ts_ls")
vim.lsp.enable("basedpyright")

-- Custom behavior for erroneous code
vim.diagnostic.config({
  underline = {
    severity = vim.diagnostic.severity.ERROR,
  },

  virtual_text = false,

  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },

    numhl = {
      [vim.diagnostic.severity.ERROR] = "DiagnosticError",
    },
  },

  severity_sort = true,
})

vim.api.nvim_set_hl(0, "DiagnosticUnderlineError", {
  undercurl = true,
  sp = "#ff0000",
})

vim.api.nvim_set_hl(0, "DiagnosticError", {
  fg = "#cc1111",
})

-- Map K to show diagnostics
vim.keymap.set("n", "K", vim.diagnostic.open_float)

-- Remap leader r to run the current file.
vim.keymap.set("n", "<leader>r", function()
  vim.cmd("write")

  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")

  local commands = {
    cpp = {
      "bash",
      "-c",
      "cpp \"$1\"",
      "_",
      file,
    },

    python = {
      "python3",
      file,
    },

    javascript = {
      "node",
      file,
    },

    typescript = {
      "tsx",
      file,
    },

    html = {
      "xdg-open",
      file,
    },
  }

  local cmd = commands[ft]

  if cmd then
    run_in_terminal(cmd)
  else
    print("No runner configured for filetype: " .. ft)
  end
end)

