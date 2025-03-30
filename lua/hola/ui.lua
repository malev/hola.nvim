local popup = require("plenary.popup")

local ui = {}

local function has_resp(state)
	return state["response"] ~= nil
end

local function has_body(state)
	return state["response"]["body"] ~= nil
end

local function shorten_string(input_string, max_length)
	max_length = max_length or 25 -- Default max length if not provided

	if #input_string > max_length then
		return string.sub(input_string, 1, max_length) .. "..."
	else
		return input_string
	end
end

local function build_metadata_content(state, maximize)
	local data = {
		"Status: " .. state.response.status,
		"Time: " .. state.response.elapsed .. "ms",
		"Headers:",
	}

	if maximize then
		for k, v in pairs(state.response.parsed_headers) do
			table.insert(data, "> " .. k .. ": " .. v)
		end
	else
		for k, v in pairs(state.response.parsed_headers) do
			table.insert(data, "> " .. k .. ": " .. shorten_string(v))
		end
	end

	return data
end

function ui.create_window(opts, cb)
	local height = 20
	local width = 30
	local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

	local win_id = popup.create(opts, {
		title = "Metadata",
		highlight = "Metadata",
		line = math.floor(((vim.o.lines - height) / 2) - 1),
		col = math.floor((vim.o.columns - width) / 2),
		minwidth = width,
		minheight = height,
		borderchars = borderchars,
		callback = cb,
	})
	local bufnr = vim.api.nvim_win_get_buf(win_id)
	vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>:HolaCloseWindow()<CR>", {})
	vim.api.nvim_buf_set_keymap(bufnr, "v", "q", "<cmd>:HolaCloseWindow()<CR>", {})
	return { buf = bufnr, win = win_id }
end

function ui.show_metadata(state)
	local values = ui.create_window(build_metadata_content(state), function() end)
	state.metadata = values
end

function ui.show_body(state)
	if not has_resp(state) then
		vim.notify("No response to show", vim.log.warning)
		return
	end

	if not has_body(state) then
		vim.notify("No body to show", vim.log.warning)
		return
	end

	local buf = vim.api.nvim_create_buf(true, true)
	local win_opts = {
		split = "right",
		win = 0,
	}
	local win = vim.api.nvim_open_win(buf, false, win_opts)
	vim.api.nvim_set_current_win(win)

	local lines = vim.split(state.response.body, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("stopinsert")

	if state.response.filetype == "json" then
		vim.api.nvim_set_option_value("filetype", "json", { buf = buf })
	end

	state["ui"] = { buf = buf, win = win, visible = true }
	return state
end

function ui.hide(state)
	if not state.ui.visible then
		return
	end
	vim.api.nvim_win_close(state.ui.win, true)
	vim.api.nvim_buf_delete(state.ui.buf, {})
	state.ui.visible = false
end

function ui.close_window(state)
	if state["metadata"] ~= nil and type(state["metadata"]) == "table" then
		vim.api.nvim_win_close(state["metadata"].win, true)
		state["metadata"] = nil
	end
end

function ui.show_window(state)
	if state["metadata"] ~= nil and type(state["metadata"]) == "table" then
		-- TODO: Validate the windows is still open
		return
	end
	ui.show_metadata(state)
end

function ui.maximize_window(state)
	ui.close_window(state)

	local bufnr = vim.api.nvim_create_buf(false, true) -- false: not listed, true: scratch buffer
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, build_metadata_content(state, true))
	return bufnr
end

return ui
