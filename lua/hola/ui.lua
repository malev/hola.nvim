local ui = {}

local function has_resp(state)
	return state["response"] ~= nil
end

local function has_body(state)
	return state["response"]["body"] ~= nil
end

function ui.create_window() end

function ui.show_info(state)
	if not has_resp(state) then
		vim.notify("No response to show", vim.log.warning)
		return
	end

	vim.notify("Status: " .. state.response.status)
	vim.notify("Elapsed: " .. state.response.elapsed .. "ms")
	vim.notify("Headers: " .. vim.inspect(state.response.headers) .. "\n")

	return state
end

function ui.show(state)
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
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { state.response.body })

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

function ui.toggle(state)
	if state.ui.visible then
		ui.hide(state)
	else
		ui.show(state)
	end
end

return ui

--
-- response = send_request(options)
--
-- state["response"] = response
--
-- show(state) --> show
-- toggle(state) --> hide --> show
-- hide(state) --> close
