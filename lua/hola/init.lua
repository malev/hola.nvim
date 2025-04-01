local M = {}

local request = require("hola.request")
local utils = require("hola.utils")
local ui = require("hola.ui")

local state = {}

M.setup = function(opts)
	opts = opts or {}
end

M.print_request = function()
	local request_text = utils.get_request_under_cursor()
	if not request_text then
		vim.notify("Failed retrieving request.", vim.log.levels.ERROR)
		return
	end
	vim.notify(request_text)
end

M.send = function()
	local request_text = utils.get_request_under_cursor()

	if not utils.validate_request_text(request_text) then
		return
	end

	vim.notify("Sending...")
	state["response"] = request.process(request_text)
	ui.show_body(state)
end

M.send_selected = function()
	local request_text, err = utils.get_visual_selection()

	if err then
		vim.notify("Failed retrieving content." .. err, vim.log.levels.ERROR)
		return
	end

	vim.notify("Sending...")
	state["response"] = request.process(request_text)
	ui.show_body(state)
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
