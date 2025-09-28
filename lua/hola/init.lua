local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local dotenv = require("hola.dotenv")
local provider_file = require("hola.provider_file")
local config = require("hola.config")
local vault_health = require("hola.vault_health")
local virtual_text = require("hola.virtual_text")

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

	-- Load provider variables from .provider file
	local provider_vars, provider_file_errors = provider_file.load()

	-- Show "Loading secrets..." if we have provider variables
	local variables = utils.extract_variables_from_text(request_text)
	local has_provider_vars = false
	for _, var in ipairs(variables) do
		if var.type == "provider" then
			has_provider_vars = true
			break
		end
	end

	-- Also check if .provider file has content
	local provider_count = 0
	for _ in pairs(provider_vars) do
		provider_count = provider_count + 1
	end
	if provider_count > 0 then
		has_provider_vars = true
	end

	-- Show appropriate loading message
	if has_provider_vars then
		virtual_text.show_provider_loading()
	else
		virtual_text.show_request_sending()
	end

	-- Handle provider file errors
	if #provider_file_errors > 0 then
		virtual_text.show_provider_error_list(provider_file_errors)
		return
	end

	-- Compile template with new precedence: OAuth -> Provider file -> .env -> OS env
	-- Provider file secrets are passed as first traditional source,
	-- but providers found in the text will also be resolved via compile_template_with_providers for backward compatibility
	local compiled_text, provider_errors = utils.compile_template_with_providers(request_text, { provider_vars, dotenv_vars, vim.env })

	-- Handle provider errors
	if #provider_errors > 0 then
		virtual_text.show_provider_error_list(provider_errors)
		return
	end

	local request_options = utils.parse_request(compiled_text)
	if not request_options then
		virtual_text.show_parse_error()
		return
	end

	-- Update to "Sending..." after secrets are loaded
	virtual_text.show_request_sending()

	local function on_request_finished(result)
		-- Check if the request resulted in an error or success
		if result.error then
			virtual_text.show_error("request", result.error)
		else
			virtual_text.show_request_success(result.status, result.elapsed_ms)
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
