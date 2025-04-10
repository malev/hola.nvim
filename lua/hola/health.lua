-- luacheck: ignore 212
local error = vim.health.error
local ok = vim.health.ok

local M = {}

--- Check if a Lua library is installed
---@param lib_name string
---@return boolean
local function lualib_installed(lib_name)
	local res, _ = pcall(require, lib_name)
	return res
end

M.check = function()
	vim.health.start("hola report")
	if vim.fn.executable("hola") == 0 then
		error("hola not found on path")
		return
	end

	if vim.fn.has("nvim-0.7.0") ~= 1 then
		error("hola requires neovim > 0.7.0")
		return
	end

	if lualib_installed("plenary") then
		ok("plenary: installed")
	else
		error('plenary: missing, required for http requests and async jobs. Install "nvim-lua/plenary.nvim" plugin.')
	end

	ok("hola is installed")
end

return M
