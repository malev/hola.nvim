-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd("set rtp+=deps/plenary.nvim")
vim.cmd([[let &rtp.=','.getcwd()]])

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.cc = "100"
vim.opt.wildmode = "longest,list"
vim.opt.expandtab = true -- use spaces instead of tabs
vim.opt.tabstop = 4 -- number of spaces that a <Tab> in the file counts for
vim.opt.softtabstop = 2 -- number of spaces that a <Tab> counts for while editing
vim.opt.shiftwidth = 2 -- number of spaces to use for each step of (auto)indent
vim.cmd("filetype plugin indent on") -- allows auto-indenting depending on file type
vim.wo.number = true

local map = vim.keymap.set

-- Hola keymaps
map("n", "<leader>hs", "<cmd>:HolaSend<cr>", { desc = "Send request" })
map("v", "<leader>hs", "<cmd>:HolaSendSelected<cr>", { desc = "Send selected request" })
map({ "n", "v" }, "<leader>hw", "<cmd>:HolaShowWindow<cr>", { desc = "Show metadata window" })
map({ "n", "v" }, "<leader>hm", "<cmd>:HolaMaximizeWindow<cr>", { desc = "Maximize metadata window" })

print("Configuration loaded.")
