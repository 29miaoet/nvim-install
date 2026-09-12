return {
  "jake-stewart/multicursor.nvim",
  branch = "1.0",

  keys = {
    { "<C-k>", mode = { "n", "x" } },
    { "<C-j>", mode = { "n", "x" } },
    { "<leader>n", mode = { "n", "x" } },
    { "<leader>N", mode = { "n", "x" } },
    { "<leader>s", mode = { "n", "x" } },
    { "<leader>S", mode = { "n", "x" } },
    { "ga", mode = { "n", "x" } },
    { "<C-leftmouse>", mode = "n" },
    { "<C-leftdrag>", mode = "n" },
    { "<C-leftrelease>", mode = "n" },
  },

  config = function()
    local mc = require("multicursor-nvim")

    mc.setup()

    local set = vim.keymap.set

    -- Add cursors above / below
    set({ "n", "x" }, "<C-k>", function()
        mc.lineAddCursor(-1)
    end, { desc = "Add cursor above" })

    set({ "n", "x" }, "<C-j>", function()
        mc.lineAddCursor(1)
    end, { desc = "Add cursor below" })

    -- Add cursor at next / previous match
    set({ "n", "x" }, "<leader>n", function()
        mc.matchAddCursor(1)
    end, { desc = "Add cursor at next match" })

    set({ "n", "x" }, "<leader>N", function()
        mc.matchAddCursor(-1)
    end, { desc = "Add cursor at previous match" })

    -- Skip next / previous match
    set({ "n", "x" }, "<leader>s", function()
        mc.matchSkipCursor(1)
    end, { desc = "Skip next match" })

    set({ "n", "x" }, "<leader>S", function()
        mc.matchSkipCursor(-1)
    end, { desc = "Skip previous match" })

    -- Add cursors using an operator
    set({ "n", "x" }, "ga", mc.addCursorOperator,
        { desc = "Add cursor operator" })

    -- Mouse cursor support
    set("n", "<C-leftmouse>", mc.handleMouse)
    set("n", "<C-leftdrag>", mc.handleMouseDrag)
    set("n", "<C-leftrelease>", mc.handleMouseRelease)

    -- Multicursor-only mappings
    mc.addKeymapLayer(function(layerSet)
      -- Cycle between cursors
      layerSet({ "n", "x" }, "<Left>", mc.prevCursor)
      layerSet({ "n", "x" }, "<Right>", mc.nextCursor)

      -- Delete the current cursor
      layerSet({ "n", "x" }, "<leader>x", mc.deleteCursor)

      -- Escape multicursor mode
      layerSet("n", "jj", function()
          mc.clearCursors()
      end)
    end)
  end,
}

