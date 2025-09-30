--- Debug Command Implementation
--- Provides the :HolaDebug command for debugging variable resolution in HTTP requests

local M = {}

local utils = require("hola.utils") -- For get_request_under_cursor
local resolution = require("hola.resolution")

--- Extract and debug variables from the current HTTP request under cursor
--- @return string debug_output Formatted debug information
function M.debug_current_request()
	-- Initialize resolution system if not already done
	local init_success = pcall(resolution.initialize)
	if not init_success then
		return "Error: Failed to initialize resolution system."
	end

	-- Get the current HTTP request text
	local request_text = utils.get_request_under_cursor()
	if not request_text then
		return "Error: No HTTP request found under cursor.\n\nPlace your cursor within an HTTP request block and try again."
	end

	-- Validate the request format
	if not utils.validate_request_text(request_text) then
		return "Error: Invalid HTTP request format.\n\nEnsure the request follows the format:\nMETHOD URL [HTTP/Version]\nHeaders...\n\nBody"
	end

	-- Use the resolution system to debug the variables
	local debug_output = resolution.debug_request_variables(request_text)

	return debug_output
end

--- Show debug information in a popup window (floating window)
--- @param debug_content string Debug content to display
function M.show_debug_popup(debug_content)
	local lines = vim.split(debug_content, "\n")

	-- Calculate popup size
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end

	-- Constrain popup size
	local max_width = math.floor(vim.o.columns * 0.8)
	local max_height = math.floor(vim.o.lines * 0.8)

	width = math.min(width, max_width)
	local height = math.min(#lines, max_height)

	-- Calculate popup position (centered)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	-- Create buffer
	local debug_bufnr = vim.api.nvim_create_buf(false, true)

	-- Set buffer options FIRST (except modifiable)
	vim.api.nvim_buf_set_option(debug_bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(debug_bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(debug_bufnr, "swapfile", false)
	vim.api.nvim_buf_set_option(debug_bufnr, "filetype", "hola-debug")

	-- Set buffer content while still modifiable
	vim.api.nvim_buf_set_lines(debug_bufnr, 0, -1, false, lines)

	-- Mark as non-modifiable LAST
	vim.api.nvim_buf_set_option(debug_bufnr, "modifiable", false)

	-- Create floating window
	local win_opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Hola Debug ",
		title_pos = "center",
	}

	local debug_winnr = vim.api.nvim_open_win(debug_bufnr, true, win_opts)

	-- Set window options
	vim.api.nvim_win_set_option(debug_winnr, "wrap", false)
	vim.api.nvim_win_set_option(debug_winnr, "number", true)
	vim.api.nvim_win_set_option(debug_winnr, "relativenumber", false)

	-- Add key mappings for the debug buffer
	local opts = { noremap = true, silent = true, buffer = debug_bufnr }
	vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
	vim.keymap.set("n", "<ESC>", "<cmd>close<cr>", opts)

	return debug_bufnr, debug_winnr
end

--- Main debug command function
--- @param opts table Command options (not used, for compatibility)
function M.debug_command(opts)
	-- Get debug information
	local debug_content = M.debug_current_request()

	-- Show debug information in popup modal
	M.show_debug_popup(debug_content)
end

--- Get provider status information
--- @return string status_info Formatted provider status
function M.get_provider_status()
	-- Initialize resolution system if not already done
	local init_success = pcall(resolution.initialize)
	if not init_success then
		return "Error: Failed to initialize resolution system."
	end

	local provider_info = resolution.get_provider_info()

	if #provider_info == 0 then
		return "No providers registered."
	end

	local lines = { "Provider Status:" }
	table.insert(lines, "")

	for _, info in ipairs(provider_info) do
		local status_icon = "✓"
		local status_text = ""

		if info.status == "failed" then
			status_icon = "✗"
			status_text = "Failed"
		elseif not info.available then
			status_icon = "✗"
			status_text = "Unavailable"
		elseif not info.enabled then
			status_icon = "○"
			status_text = "Disabled"
		else
			status_icon = "✓"
			status_text = "Ready"
		end

		table.insert(lines, string.format("%s %s - %s", status_icon, info.name, status_text))
		table.insert(lines, string.format("    Description: %s", info.description))

		-- Show error details for failed providers
		if info.status == "failed" then
			table.insert(lines, string.format("    Error: %s", info.error or "Unknown error"))
			table.insert(lines, string.format("    Reason: %s", info.reason or "unknown"))
		else
			-- Show normal details for working providers
			if info.requires_network then
				table.insert(
					lines,
					string.format("    Network: Required, Auth: %s", info.authenticated and "Yes" or "No")
				)
			end

			if info.config_files and #info.config_files > 0 then
				table.insert(lines, string.format("    Config Files: %s", table.concat(info.config_files, ", ")))
			end
		end

		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

--- Debug provider status command
--- @param opts table Command options (not used, for compatibility)
function M.provider_status_command(opts)
	-- Initialize resolution system if not already done
	local init_success = pcall(resolution.initialize)
	if not init_success then
		M.show_debug_popup("Error: Failed to initialize resolution system.")
		return
	end

	-- Attempt to load all provider definitions to get real status
	local provider_names = resolution.list_providers()
	for _, provider_name in ipairs(provider_names) do
		-- Attempt to load each provider (this may trigger auth/connection attempts)
		local _, error = resolution.load_provider(provider_name)
		if error then
			-- Provider failed to load, but that's ok - we'll show the failure in status
			vim.notify("Provider '" .. provider_name .. "' failed to load: " .. error, vim.log.levels.DEBUG)
		end
	end

	local status_info = M.get_provider_status()

	-- Show provider status in popup modal
	M.show_debug_popup(status_info)
end

--- Create debug commands
function M.setup_commands()
	-- Main debug command
	vim.api.nvim_create_user_command("HolaDebug", function(opts)
		M.debug_command(opts)
	end, {
		desc = "Debug variable resolution for the current HTTP request",
	})
end

return M
