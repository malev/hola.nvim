local popup = require("plenary.popup")
local json = require("hola.json")
local config = require("hola.config")

local M = {}

local state = {
	last_response = nil, -- Store the full result object from request.lua
	response_win_id = nil, -- Window ID for the split
	response_buf_handle = nil, -- Buffer handle for the split
	current_view = "body", -- Track what's currently shown in the split ('body' or 'headers')
	is_json_formatted = false, -- Track if current JSON is formatted
	raw_json_body = nil, -- Store raw JSON body when formatted
}

--- Formats JSON content if applicable and enabled
-- @param body_content (string) Raw body content
-- @param filetype (string) Detected filetype
-- @return (string, boolean) Processed content and whether it was formatted
local function _process_json_content(body_content, filetype)
	if filetype ~= "json" then
		return body_content, false
	end

	local json_config = config.get_json()
	if not json_config.auto_format then
		return body_content, false
	end

	local formatted, err = json.format(body_content, {
		indent_size = json_config.indent_size,
		sort_keys = json_config.sort_keys,
		compact_arrays = json_config.compact_arrays,
		max_array_length = json_config.max_array_length,
	})

	if formatted then
		return formatted, true
	else
		vim.notify("JSON formatting failed: " .. (err or "unknown error"), vim.log.levels.WARN)
		return body_content, false
	end
end

--- Sets the content and filetype of a buffer.
-- @param buf_handle (integer) The buffer handle.
-- @param content_lines (table) List of strings to set as buffer content.
-- @param filetype (string) The filetype to set.
local function _set_buffer_content(buf_handle, content_lines, filetype)
	if not vim.api.nvim_buf_is_valid(buf_handle) then
		return
	end

	vim.api.nvim_buf_set_lines(buf_handle, 0, -1, false, content_lines)
	vim.api.nvim_set_option_value("filetype", filetype, { buf = buf_handle })
	vim.api.nvim_set_option_value("modified", false, { buf = buf_handle }) -- Reset modified status

	-- Set JSON-specific options if applicable
	if filetype == "json" then
		local json_config = config.get_json()
		if json_config.enable_folding then
			vim.api.nvim_set_option_value("foldmethod", "syntax", { buf = buf_handle })
			vim.api.nvim_set_option_value("foldlevel", 2, { buf = buf_handle })
		end
		-- Set conceallevel for better JSON visualization
		vim.api.nvim_set_option_value("conceallevel", 0, { buf = buf_handle })
	end
end

--- Clears and prepares the response buffer for new content.
-- @param buf_handle (integer) The buffer handle.
-- @return (boolean)
local function _prepare_buffer(buf_handle)
	if not vim.api.nvim_buf_is_valid(buf_handle) then
		return false
	end

	_set_buffer_content(buf_handle, {}, "text")
	return true
end

--- Finds the existing response split window/buffer or creates new ones.
-- @return (table | nil) { win_id, buf_handle } or nil if creation fails.
local function _find_or_create_response_window()
	-- Check if stored handles are still valid
	if
		state.response_win_id
		and vim.api.nvim_win_is_valid(state.response_win_id)
		and state.response_buf_handle
		and vim.api.nvim_buf_is_valid(state.response_buf_handle)
	then
		-- Debug: Reusing existing response window/buffer
		return { win_id = state.response_win_id, buf_handle = state.response_buf_handle }
	end

	-- Debug: Creating new response window/buffer
	-- Window/Buffer was closed or never created, create anew
	state.response_win_id = nil
	state.response_buf_handle = nil

	-- Find current win
	local current_win = vim.api.nvim_get_current_win()

	-- Create a dedicated buffer
	local buf_handle = vim.api.nvim_create_buf(false, true) -- Not listed, scratch buffer
	if not buf_handle then
		vim.notify("Failed to create buffer", vim.log.levels.ERROR)
		return nil
	end

	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf_handle })
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf_handle })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf_handle })
	vim.api.nvim_buf_set_name(buf_handle, "REST Response")

	local win_opts = {
		split = "right",
		win = 0,
	}

	-- Create the split window
	local win_id = vim.api.nvim_open_win(buf_handle, false, win_opts)

	-- Go back to original window unless configured otherwise
	vim.api.nvim_set_current_win(current_win)

	-- Store the new handles
	state.response_win_id = win_id
	state.response_buf_handle = buf_handle

	return { win_id = win_id, buf_handle = buf_handle }
end

--- Formats parsed headers into a list of strings for display.
-- @param parsed_headers (table) Table of lowercase_key = value/list_of_values.
-- @return (table) List of strings, "Key: Value".
local function _format_headers(parsed_headers)
	local lines = {}
	-- Sort keys alphabetically for consistent display
	local sorted_keys = {}
	for k, _ in pairs(parsed_headers) do
		table.insert(sorted_keys, k)
	end
	table.sort(sorted_keys)

	for _, key in ipairs(sorted_keys) do
		local value = parsed_headers[key]
		local display_key = key:gsub("-(%l)", function(c)
			return "-" .. c:upper()
		end):gsub("^(%l)", string.upper) -- Title-Case

		if type(value) == "table" then -- Handle multi-value headers
			for _, v_item in ipairs(value) do
				table.insert(lines, display_key .. ": " .. tostring(v_item))
			end
		else
			table.insert(lines, display_key .. ": " .. tostring(value))
		end
	end
	return lines
end

--- Creates the summary line for the top of the response buffer.
-- @param result (table) The processed response object.
-- @return (string) Formatted summary line.
local function _create_summary_line(result)
	local status_text = result.status or "N/A"
	local time_text = result.elapsed_ms and string.format("%.0f ms", result.elapsed_ms) or "N/A"
	-- Add size later if calculated
	return string.format("--> [%s] [%s]", status_text, time_text)
end

--- Creates the summary for the top of the information buffer.
-- @param result (table) The processed response object.
-- @return (table) Formatted summary in a table.
local function _create_summary(result)
	local status_text = result.status or "N/A"
	local time_text = result.elapsed_ms and string.format("%.0f ms", result.elapsed_ms) or "N/A"

	return { "Status Code: " .. status_text, "Elapsed Time: " .. time_text }
end

--- Main function to display a successful response. Shows body by default.
-- @param result (table) Processed response object from request.lua.
function M.display_response(result)
	-- Debug: Displaying successful response
	state.last_response = result -- Cache the full response

	local win_info = _find_or_create_response_window()
	if not win_info then
		vim.notify("Failed to create response window", vim.log.levels.ERROR)
		return
	end -- Failed to get/create window

	local buf_handle = win_info.buf_handle
	if not _prepare_buffer(buf_handle) then
		vim.notify("Failed to create response buffer", vim.log.levels.ERROR)
		return
	end

	local summary_line = _create_summary_line(result)
	vim.notify(summary_line, vim.log.levels.INFO)

	-- Process JSON content for formatting
	local body_content = result.body or ""
	local processed_content, was_formatted = _process_json_content(body_content, result.filetype)

	-- Store formatting state and raw content
	state.is_json_formatted = was_formatted
	if was_formatted then
		state.raw_json_body = body_content
	else
		state.raw_json_body = nil
	end

	local body_lines = vim.split(processed_content, "\n")
	_prepare_buffer(buf_handle)
	_set_buffer_content(buf_handle, body_lines, result.filetype or "text")
	state.current_view = "body" -- Update state
end

--- Main function to display metadata.
function M.display_metadata()
	if state.current_view == "metadata" then
		-- Already displaying metadata
		return
	end

	if state.last_response == nil then
		vim.notify("No response to show", vim.log.levels.WARNING)
		return
	end

	local win_info = _find_or_create_response_window()

	if not win_info then
		vim.notify("Failed to create response window", vim.log.levels.ERROR)
		return
	end -- Failed to get/create window

	local buf_handle = win_info.buf_handle
	if not _prepare_buffer(buf_handle) then
		vim.notify("Failed to create response buffer", vim.log.levels.ERROR)
		return
	end

	local metadata_table = _create_summary(state.last_response)
	local headers = _format_headers(state.last_response.parsed_headers)

	table.insert(metadata_table, "")
	table.insert(metadata_table, "-- Headers --")
	table.insert(metadata_table, "")
	vim.list_extend(metadata_table, headers)

	_prepare_buffer(buf_handle)
	_set_buffer_content(buf_handle, metadata_table, "text")
	state.current_view = "metadata" -- Update state
end

function M.toggle()
	if state.last_response == nil then
		vim.notify("Nothing to display", vim.log.levels.WARNING)
		return -- No response to toggle
	end

	if state.current_view == "metadata" then
		M.display_response(state.last_response)
		return
	end

	-- I want to be explicit
	if state.current_view == "body" then
		M.display_metadata()
		return
	end
end

function M.close()
	local win_id = state.response_win_id
	if not win_id then
		vim.notify("No response window ID stored. Nothing to close", vim.log.levels.WARNING)
		return
	end

	-- Use pcall for safety when calling API functions
	local ok, closed_or_err = pcall(function()
		-- 3. Check if the window is actually still valid before trying to close
		if vim.api.nvim_win_is_valid(win_id) then
			-- 4. Close the window (false means don't force close, like :close)
			--    If the buffer had unsaved changes (unlikely for scratch), this would fail.
			--    Use true (like :close!) if you always want it gone.
			vim.api.nvim_win_close(win_id, false)
			return true -- Indicate close was attempted
		else
			vim.notify("Invalid win_id", vim.log.levels.ERROR)
			return false -- Indicate window was already gone
		end
	end)

	if not ok then
		vim.notify("Error trying to close response window: " .. tostring(closed_or_err), vim.log.levels.ERROR)
		return
	end

	state.response_win_id = nil
	state.response_buf_handle = nil
	state.current_view = "body" -- Reset view state too
	state.is_json_formatted = false -- Reset JSON state
	state.raw_json_body = nil
end

--- Toggles JSON formatting between formatted and raw views
function M.toggle_json_format()
	if not state.last_response then
		vim.notify("No response to format", vim.log.levels.WARNING)
		return
	end

	if state.last_response.filetype ~= "json" then
		vim.notify("Current response is not JSON", vim.log.levels.WARNING)
		return
	end

	if state.current_view ~= "body" then
		vim.notify("JSON formatting only available in body view", vim.log.levels.WARNING)
		return
	end

	local win_info = _find_or_create_response_window()
	if not win_info then
		vim.notify("Failed to create response window", vim.log.levels.ERROR)
		return
	end

	local buf_handle = win_info.buf_handle
	local new_content
	local new_formatted_state

	if state.is_json_formatted then
		-- Switch to raw JSON
		new_content = state.raw_json_body or state.last_response.body or ""
		new_formatted_state = false
		vim.notify("Showing raw JSON", vim.log.levels.INFO)
	else
		-- Switch to formatted JSON
		local body_content = state.raw_json_body or state.last_response.body or ""
		local formatted, err = json.format(body_content, config.get_json())
		if formatted then
			new_content = formatted
			new_formatted_state = true
			if not state.raw_json_body then
				state.raw_json_body = body_content
			end
			vim.notify("Showing formatted JSON", vim.log.levels.INFO)
		else
			vim.notify("JSON formatting failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
			return
		end
	end

	-- Update buffer content
	local content_lines = vim.split(new_content, "\n")
	_set_buffer_content(buf_handle, content_lines, "json")
	state.is_json_formatted = new_formatted_state
end

--- Validates current JSON response
function M.validate_json()
	if not state.last_response then
		vim.notify("No response to validate", vim.log.levels.WARNING)
		return
	end

	if state.last_response.filetype ~= "json" then
		vim.notify("Current response is not JSON", vim.log.levels.WARNING)
		return
	end

	local body_content = state.raw_json_body or state.last_response.body or ""
	local is_valid, error_msg = json.validate(body_content)

	if is_valid then
		vim.notify("JSON is valid", vim.log.levels.INFO)
	else
		vim.notify("JSON validation failed: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
	end
end

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

function M.create_window(opts, cb)
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

function M.show_body(state)
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

function M.hide(state)
	if not state.ui.visible then
		return
	end
	vim.api.nvim_win_close(state.ui.win, true)
	vim.api.nvim_buf_delete(state.ui.buf, {})
	state.ui.visible = false
end

function M.close_window(state)
	if state["metadata"] ~= nil and type(state["metadata"]) == "table" then
		vim.api.nvim_win_close(state["metadata"].win, true)
		state["metadata"] = nil
	end
end

function M.show_window(state)
	if state["metadata"] ~= nil and type(state["metadata"]) == "table" then
		-- TODO: Validate the windows is still open
		return
	end
	M.show_metadata(state)
end

function M.maximize_window(state)
	M.close_window(state)

	local bufnr = vim.api.nvim_create_buf(false, true) -- false: not listed, true: scratch buffer
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, build_metadata_content(state, true))
	return bufnr
end

--- Clears the content of the buffer associated with the given feedback information.
---
--- @param feedback_info table: A table containing the buffer and window information:
---   - buf (number): The buffer number. If not provided, it will be retrieved from the window.
---   - win (number): The window number.
---
--- @return table: A table containing the buffer and window information:
---   - buf (number): The buffer number.
---   - win (number): The window number.
function M.clear_sending_feedback(feedback_info)
	local buf = feedback_info.buf
	local win = feedback_info.win
	if not buf then
		buf = vim.api.nvim_win_get_buf(win)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

	return { buf = buf, win = win }
end

return M
