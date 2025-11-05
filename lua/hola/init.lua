local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local config = require("hola.config")
local vault_health = require("hola.vault_health")
local virtual_text = require("hola.virtual_text")
local resolution = require("hola.resolution")
local file_writer = require("hola.file_writer")

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

--- Saves the last response to a file
-- @param file_path (string) The path where to save the response
function M.save_last_response(file_path)
	-- Get the last response
	local last_response = ui.get_last_response()

	if not last_response then
		vim.notify("No response to save", vim.log.levels.WARN)
		return
	end

	-- Validate file path
	if not file_path or vim.fn.trim(file_path) == "" then
		vim.notify("Please provide a file path", vim.log.levels.ERROR)
		return
	end

	-- Save the response
	local save_ok, save_result = file_writer.save_response(last_response, file_path)

	if save_ok then
		vim.notify("Response saved to: " .. save_result, vim.log.levels.INFO)
	else
		vim.notify("Failed to save response: " .. save_result, vim.log.levels.ERROR)
	end
end

function M.run_request_under_cursor()
	-- 1. Get request text
	local request_text = utils.get_request_under_cursor()
	if not request_text then
		vim.notify("No request found.", vim.log.levels.ERROR)
		return
	end

	-- 2. Parse output directive before removing comments
	local output_file = utils.parse_output_directive(request_text)

	-- 3. Basic validation (optional, parse might handle some)
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

			-- Save to file if output directive was specified
			if output_file then
				local save_ok, save_result = file_writer.save_response(result, output_file)
				if save_ok then
					vim.notify("Response saved to: " .. save_result, vim.log.levels.INFO)
				else
					vim.notify("Failed to save response: " .. save_result, vim.log.levels.ERROR)
				end
			end

			-- Display response in UI
			ui.display_response(result)
		end
	end

	request.execute(request_options, on_request_finished)
end

return M
