local M = {}

local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")
local dotenv = require("hola.dotenv")

local state = {}

local function preflight(request_text)
	if not utils.validate_request_text(request_text) then
		vim.notify("Invalid request format.", vim.log.levels.ERROR)
		return
	end

	local sources = { dotenv.load(), vim.env }

	vim.notify("Sending...")
	state["response"] = request.process(request_text, sources)
	ui.show_body(state)
end

M.setup = function(opts)
	opts = opts or {}
end

M.send = function()
	local request_text = utils.get_request_under_cursor()
	preflight(request_text)
end

M.send_selected = function()
	local request_text, err = utils.get_visual_selection()

	if err then
		vim.notify("Failed retrieving content." .. err, vim.log.levels.ERROR)
		return
	end

	preflight(request_text)
end

M.close_window = function()
	ui.close_window(state)
end

M.show_window = function()
	ui.show_window(state)
end

M.maximize_window = function()
	ui.maximize_window(state)
end

return M
