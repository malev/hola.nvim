local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local dotenv = require("hola.dotenv")

local M = {}

function M.display_metadata()
	ui.display_metadata()
end

function M.close()
	ui.close()
end

function M.toggle()
	ui.toggle()
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
	local compiled_text = utils.compile_template(request_text, { dotenv_vars, vim.env })
	local request_options = utils.parse_request(compiled_text)
	if not request_options then
		vim.notify("Failed to parse request options.", vim.log.levels.ERROR)
		return
	end

	local function on_request_finished(result)
		-- Check if the request resulted in an error or success
		if result.error then
			print("there was an error", vim.inspect(result))
		else
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
	local compiled_text = utils.compile_template(request_text, { dotenv_vars, vim.env })
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

return M
