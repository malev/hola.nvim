local M = {}

local utils = require("hola.utils")
local ui = require("hola.ui")

local state = {}

local function get_visual_selection()
	vim.cmd("normal! gv") -- Re-select the visual selection
	local mode = vim.fn.visualmode()

	if mode == "" then
		return nil, "Not in visual mode"
	end

	-- Get the start and end positions of the visual selection
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	local start_col = vim.fn.col("'<")
	local end_col = vim.fn.col("'>")

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false) -- Get lines

	if mode == "v" then -- Character-wise
		if #lines == 1 then
			return lines[1]:sub(start_col, end_col - 1)
		else
			local result = {}
			result[1] = lines[1]:sub(start_col)
			for i = 2, #lines - 1 do
				table.insert(result, lines[i])
			end
			result[#lines] = lines[#lines]:sub(1, end_col - 1)
			return table.concat(result, "\n")
		end
	elseif mode == "V" then -- Line-wise
		return table.concat(lines, "\n")
	elseif mode == "<C-v>" then -- Block-wise
		local result = {}
		for i = 1, #lines do
			table.insert(result, lines[i]:sub(start_col, end_col - 1))
		end
		return table.concat(result, "\n")
	else
		return nil, "Unsupported visual mode: " .. mode
	end
end

M.setup = function(opts)
	opts = opts or {}

	-- vim.api.nvim_create_user_command("Send", "require('hola').send_selected()", {})
	-- vim.api.nvim_command('command! Send lua require("hola").send_selected()')
	-- vim.keymap.set("v", "<leader>h", "<esc>:lua M.start()<cr>", { noremap = true })
end

function M.add_numbers(a, b)
	return a + b
end

function M.greet(name)
	return "Hello, " .. name .. "!"
end

M.create_window = function()
	print("create window")
	local buf = vim.api.nvim_create_buf(true, true)
	local win_opts = {
		split = "right",
		win = 0,
	}
	local win = vim.api.nvim_open_win(buf, false, win_opts)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hola" })
	vim.api.nvim_set_option_value("filetype", "json", { buf = buf })

	return { buf = buf, win = win }
end

M.toggle = function()
	ui.toggle(state)
end

M.hide = function()
	ui.hide(state)
end

M.send_selected = function()
	local content, err = get_visual_selection()

	if err then
		vim.notify("Failed retrieving content." .. err, vim.log.levels.ERROR)
		return
	end

	vim.notify("Sending...")
	state["response"] = utils.process(content)

	ui.show_info(state)
	ui.show(state)
end

return M
