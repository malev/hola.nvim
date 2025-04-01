local M = {}

local SEPARATOR_PATTERN = "^###" -- Define pattern once
local separator_regex = vim.regex(SEPARATOR_PATTERN)

--- Helper to check if a line matches the separator pattern.
-- @param bufnr (integer) Buffer handle.
-- @param line_1based (integer) 1-based line number to check.
-- @return (boolean) True if the line matches the separator pattern.
local function _is_separator_line(bufnr, line_1based)
	-- 1. Boundary Check: Is the requested line number valid?
	if line_1based < 1 or line_1based > vim.api.nvim_buf_line_count(bufnr) then
		-- Trying to check a line outside the buffer's range. Definitely not a separator.
		return false
	end
	-- 2. Fetch the Line Content:
	-- Use nvim_buf_get_lines which is 0-indexed and end-exclusive.
	-- To get only line `line_1based`, we ask for the range [line_1based - 1, line_1based).
	local line_content_table = vim.api.nvim_buf_get_lines(bufnr, line_1based - 1, line_1based, false)
	-- 3. Check if a line was actually returned and perform the match:
	-- Check if the table is not empty (i.e., the line exists)
	if #line_content_table > 0 then
		-- Get the actual string content from the table
		local line_string = line_content_table[1]
		local match_result = separator_regex:match_str(line_string)
		return match_result ~= nil
	else
		-- nvim_buf_get_lines returned an empty table. This shouldn't happen
		-- if the boundary check passed, but defensively, we return false.
		return false
	end
end

--- Adjusts the cursor row if it's directly on a separator line.
-- Treats it as belonging to the request *before* the separator.
-- @param bufnr (integer) Buffer handle.
-- @param cursor_row_1based (integer) Original 1-based cursor row.
-- @return (integer) Effective 1-based cursor row for finding boundaries.
local function _get_effective_cursor_row(bufnr, cursor_row_1based)
	if cursor_row_1based > 1 and _is_separator_line(bufnr, cursor_row_1based) then
		return cursor_row_1based - 1
	end
	return cursor_row_1based
end

--- Finds the starting line (1-based) of the request block.
-- @param bufnr (integer) Buffer handle.
-- @param effective_cursor_row (integer) Adjusted 1-based cursor row.
-- @return (integer) 1-based start line number.
local function _find_start_line(bufnr, effective_cursor_row)
	-- Search backwards from the line *above* the effective cursor position
	for i = effective_cursor_row - 1, 1, -1 do
		if _is_separator_line(bufnr, i) then
			return i + 1 -- Request starts on the line *after* the separator
		end
	end
	return 1 -- Default: start from the beginning
end

--- Finds the ending line (1-based) of the request block.
-- @param bufnr (integer) Buffer handle.
-- @param effective_cursor_row (integer) Adjusted 1-based cursor row.
-- @param total_lines (integer) Total lines in the buffer.
-- @return (integer) 1-based end line number.
local function _find_end_line(bufnr, effective_cursor_row, total_lines)
	-- Search forwards from the effective cursor position
	for i = effective_cursor_row, total_lines do
		if _is_separator_line(bufnr, i) then
			return i - 1 -- Request ends on the line *before* the separator
		end
	end
	return total_lines -- Default: end at the last line
end

--- Validates the range and handles the edge case where the cursor is on the first line separator.
-- @param bufnr (integer) Buffer handle.
-- @param start_line (integer) Proposed start line (1-based).
-- @param end_line (integer) Proposed end line (1-based).
-- @param cursor_row_1based (integer) Original cursor row (1-based).
-- @param total_lines (integer) Total lines in the buffer.
-- @return (table|nil) A table {start_line=s, end_line=e} if valid, else nil.
local function _validate_and_adjust_range(bufnr, start_line, end_line, cursor_row_1based, total_lines)
	if start_line <= end_line then
		return { start_line = start_line, end_line = end_line } -- Range is initially valid
	end

	-- Handle invalid range, potentially due to cursor on the first line separator.
	if cursor_row_1based == 1 and _is_separator_line(bufnr, 1) then
		-- Cursor was on separator at line 1, find the *next* block instead
		local next_start_line = 2
		if next_start_line > total_lines then
			vim.notify("No content after separator on line 1", vim.log.levels.WARN)
			return nil -- No lines after the first one
		end
		local next_end_line = _find_end_line(bufnr, next_start_line, total_lines)

		if next_start_line <= next_end_line then
			return { start_line = next_start_line, end_line = next_end_line }
		else
			vim.notify("Could not find request block after separator on line 1", vim.log.levels.WARN)
			return nil
		end
	else
		-- General invalid range, likely cursor after last actual request content.
		vim.notify("Could not determine request block boundaries.", vim.log.levels.WARN)
		return nil
	end
end

--- Fetches lines within the given range and returns them as a single trimmed string.
-- @param bufnr (integer) Buffer handle.
-- @param start_line_1based (integer) 1-based start line.
-- @param end_line_1based (integer) 1-based end line.
-- @return (string) The combined and trimmed text of the request block.
local function _get_lines_as_string(bufnr, start_line_1based, end_line_1based)
	if start_line_1based > end_line_1based or start_line_1based < 1 then
		return "" -- Invalid range yields empty string
	end

	-- Fetch the lines of the request block (0-indexed start, exclusive end)
	local request_lines = vim.api.nvim_buf_get_lines(bufnr, start_line_1based - 1, end_line_1based, false)

	if #request_lines == 0 then
		return ""
	end

	local request_text = table.concat(request_lines, "\n")
	return vim.fn.trim(request_text) -- Trim leading/trailing whitespace/newlines
end

--- Validates if the provided text block appears to start with a valid HTTP request line.
-- Checks for METHOD URL [HTTP/Version] structure on the first non-empty, non-comment line.
-- Case-sensitive check for standard uppercase HTTP methods.
--
-- @param request_text (string) The raw text block extracted for a potential request.
-- @return (boolean) True if the text seems to represent a structurally valid request, false otherwise.
local function validate_request_text(request_text)
	if request_text == nil or vim.fn.trim(request_text) == "" then
		vim.notify("Request block is empty.", vim.log.levels.WARN, { title = "REST Client Validation" })
		return false
	end

	local lines = vim.split(request_text, "\n", true)
	local request_line = nil
	for _, line in ipairs(lines) do
		local trimmed_line = vim.fn.trim(line)
		-- Use Lua pattern here for simple comment check, it's fine
		if trimmed_line ~= "" and not trimmed_line:match("^%s*#") then
			request_line = trimmed_line
			break
		end
	end

	if request_line == nil then
		vim.notify(
			"Request block contains no actionable lines.",
			vim.log.levels.WARN,
			{ title = "REST Client Validation" }
		)
		return false
	end

	-- Vim Regex Pattern string (note escaped alternation '\|', grouping '\(...\)')
	local vim_pattern =
		[[^\(GET\|POST\|PUT\|DELETE\|PATCH\|HEAD\|OPTIONS\|CONNECT\|TRACE\)\s\+\(\S\+\)\(\s\+HTTP/\d\.\d\)\?\s*$]]

	-- Use vim.fn.matchlist(text, pattern)
	-- It returns a list (table). Index 0 = full match, 1 = capture 1, 2 = capture 2, etc.
	-- Returns an empty list {} if there is no match.
	local match_list = vim.fn.matchlist(request_line, vim_pattern)

	-- Check if the list is not empty (match occurred) and if required capture groups were filled
	-- Group 1 (index 1) is METHOD, Group 2 (index 2) is URL
	if #match_list > 0 and match_list[2] and match_list[2] ~= "" and match_list[3] and match_list[3] ~= "" then
		-- We successfully matched and got non-empty METHOD (list[2]) and URL (list[3])
		-- Note: matchlist uses 1-based indexing for Lua tables. list[1] is capture group 1.
		return true
	else
		vim.notify(
			"Invalid request format. Expected 'METHOD URL [HTTP/Version]'. Found:\n" .. request_line,
			vim.log.levels.WARN,
			{ title = "REST Client Validation" }
		)
		return false
	end
end

--- Finds and returns the HTTP request text block surrounding the current cursor position.
-- Requests are expected to be separated by lines starting with '###'.
--
-- @return (string|nil) The text of the request block, or nil if not found or in case of error.
local function get_request_under_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor_row_1based = vim.api.nvim_win_get_cursor(0)[1] -- 1-based line number

	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	if total_lines == 0 then
		vim.notify("Buffer is empty", vim.log.levels.WARN)
		return nil
	end

	local effective_cursor_row = _get_effective_cursor_row(bufnr, cursor_row_1based)
	-- Handle edge case where effective cursor row becomes < 1 (only if cursor was on line 1 separator)
	if effective_cursor_row < 1 then
		effective_cursor_row = 1
	end

	local start_line = _find_start_line(bufnr, effective_cursor_row)
	local end_line = _find_end_line(bufnr, effective_cursor_row, total_lines)

	local range = _validate_and_adjust_range(bufnr, start_line, end_line, cursor_row_1based, total_lines)

	if not range then
		return nil -- Validation failed, message already shown
	end

	-- Ensure final start_line is within buffer bounds after potential adjustments
	if range.start_line > total_lines then
		vim.notify("Calculated start line is beyond buffer end.", vim.log.levels.WARN)
		return nil
	end

	return _get_lines_as_string(bufnr, range.start_line, range.end_line)
end

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

M = {
	validate_request_text = validate_request_text,
	get_visual_selection = get_visual_selection,
	get_request_under_cursor = get_request_under_cursor,
}

return M
