return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
      vim.opt.termguicolors = true

      require("catppuccin").setup({
        flavour = "mocha",
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
