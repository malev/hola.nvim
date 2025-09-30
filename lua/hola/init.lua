local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local config = require("hola.config")
local vault_health = require("hola.vault_health")
local virtual_text = require("hola.virtual_text")
local resolution = require("hola.resolution")

local M = {}

--- Setup function to initialize hola.nvim with user configuration
-- @param opts (table|nil) User configuration options
function M.setup(opts)
	config.setup(opts)

	-- Initialize the new resolution system
	resolution.initialize()
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

	-- Check if we have any provider variables to resolve
	local has_variables = request_text:match("{{[^}]+}}")
	if has_variables then
		virtual_text.show_provider_loading()
	else
		virtual_text.show_request_sending()
	end

	-- Resolve all variables using the new resolution system
	local compiled_text, resolution_errors = resolution.resolve_variables(request_text, {})

	-- Handle resolution errors
	if #resolution_errors > 0 then
		virtual_text.show_provider_error_list(resolution_errors)
		return
	end

	local request_options = utils.parse_request(compiled_text)
	if not request_options then
		virtual_text.show_parse_error()
		return
	end

	-- Update to "Sending..." after variables are resolved
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




return M
