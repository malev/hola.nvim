-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd("set rtp+=deps/plenary.nvim")

vim.cmd("source plugin/hola.lua")

-- Enable vault for development/testing
require("hola").setup({
	vault = {
		enabled = true
	}
})
