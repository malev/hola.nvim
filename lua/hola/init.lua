local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local dotenv = require("hola.dotenv")
local config = require("hola.config")
local vault_health = require("hola.vault_health")

local M = {}

--- Setup function to initialize hola.nvim with user configuration
-- @param opts (table|nil) User configuration options
function M.setup(opts)
	config.setup(opts)

	-- If vault is enabled, perform a quick health check and show warnings if needed
	local vault_config = config.get_vault()
	if vault_config.enabled then
		local valid, message, suggestion = vault_health.validate_vault_requirements()
		if not valid then
			vim.notify("hola.nvim vault: " .. message, vim.log.levels.WARN)
			if suggestion then
				vim.notify("Suggestion: " .. suggestion, vim.log.levels.INFO)
			end
		end
	end
end

function M.display_metadata()
	ui.display_metadata()
end

function M.close()
	ui.close()
end

function M.toggle()
	ui.toggle()
end

--- Toggle JSON formatting between formatted and raw views
function M.toggle_json_format()
	ui.toggle_json_format()
end

function M.run_request_under_cursor()
	-- 1. Get request text
	local request_text = utils.get_request_under_cursor()
	if not request_text then
		vim.notify("No request found.", vim.log.levels.ERROR)
		return
	end

	-- 2. Basic validation (optional, parse might handle some)
	if not utils.validate_request_text(request_text) then
		vim.notify("Invalid request structure.", vim.log.levels.ERROR)
		return
	end

	local dotenv_vars = dotenv.load() -- Returns {} if none found

	-- Show "Loading secrets..." if we have provider variables
	local variables = utils.extract_variables_from_text(request_text)
	local has_provider_vars = false
	for _, var in ipairs(variables) do
		if var.type == "provider" then
			has_provider_vars = true
			break
		end
	end

	-- Get the current cursor position for virtual text
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line = cursor_pos[1] - 1 -- Convert to 0-based index
	local col = cursor_pos[2]

	-- Create a namespace for our virtual text
	local ns_id = vim.api.nvim_create_namespace("hola_request_status")
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1) -- Clear any previous virtual text

	-- Show appropriate loading message
	if has_provider_vars then
		vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
			virt_text = { { "🔐Loading secrets from providers...", "Comment" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
	else
		vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
			virt_text = { { "⏳Sending...", "Comment" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
	end

	-- Compile template with provider support
	local compiled_text, provider_errors = utils.compile_template_with_providers(request_text, { dotenv_vars, vim.env })

	-- Handle provider errors
	if #provider_errors > 0 then
		local error_msg = "Provider errors: "
		for i, err in ipairs(provider_errors) do
			error_msg = error_msg .. err.variable .. " (" .. err.error .. ")"
			if i < #provider_errors then
				error_msg = error_msg .. ", "
			end
		end

		vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
		vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
			virt_text = { { "❗" .. error_msg, "ErrorMsg" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
		return
	end

	local request_options = utils.parse_request(compiled_text)
	if not request_options then
		vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
		vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
			virt_text = { { "❗Failed to parse request", "ErrorMsg" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
		return
	end

	-- Update to "Sending..." after secrets are loaded
	vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
	vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
		virt_text = { { "⏳Sending...", "Comment" } },
		virt_text_pos = "eol",
		hl_mode = "combine",
	})

	local function on_request_finished(result)
		-- Remove the "Sending..." virtual text
		vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)

		-- Check if the request resulted in an error or success
		if result.error then
			-- Show error status
			vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
				virt_text = { { "❗Error: " .. result.error, "ErrorMsg" } },
				virt_text_pos = "eol",
				hl_mode = "combine",
			})
		else
			-- Show success status with status code and elapsed time
			local elapsed_text = result.elapsed_ms and string.format("%.0fms", result.elapsed_ms) or "?ms"
			local status_text = "✔️Response: " .. (result.status or "Unknown") .. " (" .. elapsed_text .. ")"
			vim.api.nvim_buf_set_extmark(0, ns_id, line, col, {
				virt_text = { { status_text, "Comment" } },
				virt_text_pos = "eol",
				hl_mode = "combine",
			})
			ui.display_response(result)
		end
	end

	request.execute(request_options, on_request_finished)
end

M.run_selected_request = function()
	local request_text, err = utils.get_visual_selection()
	if err then
		vim.notify("Failed retrieving content." .. err, vim.log.levels.ERROR)
		return
	end

	local dotenv_vars = dotenv.load() -- Returns {} if none found

	-- Compile template with provider support
	local compiled_text, provider_errors = utils.compile_template_with_providers(request_text, { dotenv_vars, vim.env })

	-- Handle provider errors
	if #provider_errors > 0 then
		local error_msg = "Provider errors: "
		for i, err in ipairs(provider_errors) do
			error_msg = error_msg .. err.variable .. " (" .. err.error .. ")"
			if i < #provider_errors then
				error_msg = error_msg .. ", "
			end
		end
		vim.notify(error_msg, vim.log.levels.ERROR)
		return
	end

	local request_options = utils.parse_request(compiled_text)
	if not request_options then
		vim.notify("Failed to parse request options.", vim.log.levels.ERROR)
		return
	end

	local function on_request_finished(result)
		-- Check if the request resulted in an error or success
		if result.error then
			vim.notify("Request failed", vim.log.levels.INFO)
		else
			ui.display_response(result)
		end
	end

	request.execute(request_options, on_request_finished)
end

--- Show vault health status
function M.show_vault_status()
	vault_health.show_vault_status()
end

--- Enable vault integration mid-session
function M.enable_vault()
	local current_config = config.get()
	current_config.vault.enabled = true

	-- Run health check and show results
	local valid, message, suggestion = vault_health.validate_vault_requirements()
	if valid then
		vim.notify("✓ Vault integration enabled and ready!", vim.log.levels.INFO)
	else
		vim.notify("⚠ Vault integration enabled but: " .. message, vim.log.levels.WARN)
		if suggestion then
			vim.notify("Suggestion: " .. suggestion, vim.log.levels.INFO)
		end
	end
end

--- Disable vault integration mid-session
function M.disable_vault()
	local current_config = config.get()
	current_config.vault.enabled = false
	vim.notify("Vault integration disabled", vim.log.levels.INFO)
end

return M
