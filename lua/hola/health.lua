-- luacheck: ignore 212
local error = vim.health.error
local ok = vim.health.ok
local warn = vim.health.warn
local info = vim.health.info

local M = {}

--- Check if a Lua library is installed
---@param lib_name string
---@return boolean
local function lualib_installed(lib_name)
	local res, _ = pcall(require, lib_name)
	return res
end

--- Check vault health using the vault_health module
local function check_vault_health()
	local vault_health = require("hola.vault_health")

	vim.health.start("hola vault integration")

	-- Run vault health checks
	local checks = vault_health.check_vault()

	for _, check in ipairs(checks) do
		local result = check.result
		local message = check.name .. ": " .. result.message

		if result.level == "OK" then
			ok(message)
		elseif result.level == "WARN" then
			warn(message)
			if result.suggestion then
				info("  → " .. result.suggestion)
			end
		else -- INFO
			info(message)
		end
	end

	-- Summary message
	local has_warnings = false
	for _, check in ipairs(checks) do
		if check.result.level == "WARN" then
			has_warnings = true
			break
		end
	end

	if not has_warnings then
		ok("Vault integration ready")
	else
		warn("Vault features will be disabled due to warnings above")
	end
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

	-- Add vault health checks
	check_vault_health()
end

return M
