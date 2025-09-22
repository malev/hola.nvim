local M = {}

local SEPARATOR_PATTERN = "^###" -- Define pattern once
local separator_regex = vim.regex(SEPARATOR_PATTERN)

--- Removes leading/trailing whitespace from a string.
-- @param s (string) Input string.
-- @return (string) Trimmed string.
local function trim(s)
	if not s then
		return ""
	end
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Splits a string into a table of substrings using a specified delimiter.
-- This function performs a plain (literal) string match for the delimiter.
-- @param str The string to be split.
-- @param delimiter The string used to separate the substrings.
-- @return A table containing the substrings. If the delimiter is not found,
--        the table will contain the original string as its only element.
--        Empty delimiters will lead to unexpected behavior.
function split(str, delimiter)
	local results = {}
	local start = 1
	local delimiter_len = #delimiter

	while true do
		local s = string.find(str, delimiter, start, true) -- plain match
		if s then
			local segment = string.sub(str, start, s - 1)
			table.insert(results, segment)
			start = s + delimiter_len
		else
			table.insert(results, string.sub(str, start))
			break
		end
	end

	return results
end

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

--- Removes lines that consist entirely of comments.
-- A comment line starts with '#', potentially preceded by whitespace.
-- Preserves blank lines and lines that have non-comment content.
-- @param str (string) The input multi-line string.
-- @return (string) The string with comment-only lines removed.
function M.remove_comments(str)
	-- Handle nil or empty input gracefully
	if not str or str == "" then
		return ""
	end

	-- Split the input string into a table of lines.
	-- The second argument ('\n') is the separator.
	local lines = vim.split(str, "\n")

	-- Create a table to hold the lines we want to keep.
	local kept_lines = {}

	-- Iterate through the original lines.
	for _, line in ipairs(lines) do
		-- Check if the line starts with optional whitespace followed by '#'.
		-- string.match returns the matched portion (truthy) or nil (falsy).
		if not line:match("^%s*#") then
			-- If the pattern does NOT match, it means the line is NOT a comment-only line.
			-- Keep this line.
			table.insert(kept_lines, line)
		end
		-- Implicit else: If the line *is* a comment line (matches the pattern),
		-- we simply do nothing, effectively filtering it out.
	end

	-- Join the lines we kept back into a single string, separated by newlines.
	return table.concat(kept_lines, "\n")
end

--- Validates if the provided text block appears to start with a valid HTTP request line.
-- Checks for METHOD URL [HTTP/Version] structure on the first non-empty, non-comment line.
-- Case-sensitive check for standard uppercase HTTP methods.
--
-- @param request_text (string) The raw text block extracted for a potential request.
-- @return (boolean) True if the text seems to represent a structurally valid request, false otherwise.
function M.validate_request_text(request_text)
	if request_text == nil or vim.fn.trim(request_text) == "" then
		vim.notify("Request block is empty.", vim.log.levels.WARN, { title = "REST Client Validation" })
		return false
	end

	local lines = vim.split(request_text, "\n")
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
function M.get_request_under_cursor()
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

function M.get_visual_selection()
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

--- Compiles a template string by replacing {{var_name}} placeholders.
-- Dotenv takes precedence over OS env.
--
-- @param str (string) The template string.
-- @return (string|nil) The compiled string, or nil if strict mode fails.
function M.compile_template(str, sources)
	if not str then
		return ""
	end

	local result = str:gsub("{{([^}]+)}}", function(var_name_raw)
		local var_name = vim.fn.trim(var_name_raw) -- Trim whitespace within braces
		local found_value = nil

		-- Search through the provided sources in order (e.g., dotenv first)
		for _, source_table in ipairs(sources) do
			if source_table and source_table[var_name] ~= nil then
				found_value = source_table[var_name]
				break -- Found in this source, stop searching
			end
		end

		if found_value ~= nil then
			-- Convert to string in case value was boolean/number from .env
			return tostring(found_value)
		else
			vim.notify("Template variable not found: " .. var_name, vim.log.levels.ERROR, { title = "Template Error" })
			-- Return original placeholder to signal failure within gsub for the outer check
			return "{{" .. var_name_raw .. "}}"
		end
	end)
	return result
end

--- Encodes a username:password string to base64 for Basic Authentication.
-- @param credentials (string) The credentials in format "username:password"
-- @return (string) Base64 encoded credentials
function M.encode_basic_auth(credentials)
	if not credentials or credentials == "" then
		return ""
	end

	-- Use vim.base64.encode for encoding
	return vim.base64.encode(credentials)
end

--- Detects if an Authorization header value needs Basic Auth encoding.
-- @param auth_value (string) The authorization header value (after "Basic ")
-- @return (boolean) True if the value looks like it needs encoding (contains colon, not already base64)
local function _needs_basic_auth_encoding(auth_value)
	if not auth_value or auth_value == "" then
		return false
	end

	-- Check if it contains a colon (indicating username:password format)
	if not auth_value:find(":") then
		return false
	end

	-- Simple heuristic: if it looks like base64 (only contains base64 chars and proper padding),
	-- assume it's already encoded. This is not foolproof but works for most cases.
	-- Base64 chars: A-Z, a-z, 0-9, +, /, = (for padding)
	if auth_value:match("^[A-Za-z0-9+/]*=*$") and not auth_value:find("%s") then
		-- Could be base64, but let's be more specific: check if it decodes to something with a colon
		local success, decoded = pcall(vim.base64.decode, auth_value)
		if success and decoded and decoded:find(":") then
			-- It's already properly encoded
			return false
		end
	end

	return true
end

--- Processes Authorization header for automatic Basic Auth encoding.
-- @param headers (table) The headers table with lowercase keys
-- @return (table) The headers table with potentially modified authorization header
local function _process_auth_header(headers)
	local auth_header = headers["authorization"]
	if not auth_header then
		return headers
	end

	-- Check if it's a Basic auth header
	local basic_prefix = "Basic "
	if auth_header:sub(1, #basic_prefix):lower() == basic_prefix:lower() then
		local auth_value = auth_header:sub(#basic_prefix + 1)

		if _needs_basic_auth_encoding(auth_value) then
			-- Encode the credentials
			local encoded = M.encode_basic_auth(auth_value)
			headers["authorization"] = "Basic " .. encoded
		end
	end

	return headers
end

--- Parses the request text block into its components.
-- Expects the first line to be METHOD URL [HTTP/Version].
-- Headers are key:value pairs.
-- A blank line separates headers from the body.
-- Normalizes header keys to lowercase.
--
-- @param content (string) The request text block (multiline).
-- @return (table|nil) A table with keys {method, path, http_version, headers, body} on success,
--                     or nil if the request line is fundamentally invalid.
function M.parse_request(content)
	-- 1. Handle nil or effectively empty input
	if not content or vim.fn.trim(content) == "" then
		vim.notify("Cannot parse empty request content.", vim.log.levels.WARN)
		return nil
	end

	-- 2. Initialize output structure and state
	local output = {
		method = "",
		path = "",
		http_version = nil, -- Explicitly nil if not present
		headers = {}, -- Store keys lowercase
		body = "",
	}
	local body_lines = {}
	local parsing_headers = true -- Start assuming we parse headers after line 1
	local lines = vim.split(content, "\n")

	-- 3. Iterate through lines
	for i, line in ipairs(lines) do
		if i == 1 then
			-- Parse the Request Line (METHOD URL [HTTP/Version])
			local request_line_parts = vim.split(line, "%s+", { trimempty = true })
			if #request_line_parts < 2 then
				vim.notify(
					"Invalid request line format: Must contain at least METHOD and URL.",
					vim.log.levels.ERROR,
					{ title = "Request Parse Error" }
				)
				return nil -- Cannot proceed without method and URL
			end
			-- Note: We rely on previous validation for METHOD correctness.
			output.method = request_line_parts[1]
			output.path = request_line_parts[2]
			if #request_line_parts >= 3 then
				-- Basic check if the third part looks like HTTP version
				if request_line_parts[3]:match("^HTTP/%d%.%d$") then
					output.http_version = request_line_parts[3]
				else
					-- Treat as part of the URL if it doesn't look like HTTP/x.y
					-- This handles URLs with spaces if not quoted, although uncommon/problematic
					-- Re-join parts from index 2 onwards for the path
					output.path = table.concat(request_line_parts, " ", 2)
					vim.notify(
						"Suspicious request line format. Treating extra parts as URL.",
						vim.log.levels.WARN,
						{ title = "Request Parse Warning" }
					)
				end
			end
		elseif parsing_headers then
			-- Trim whitespace from the line for structure checks
			local trimmed_line = vim.fn.trim(line)

			-- Check for the blank line separating headers and body
			if trimmed_line == "" then
				parsing_headers = false
			else
				-- Parse Header line (Key: Value)
				-- Match up to the first colon for the key, rest is value
				local key, value = line:match("^([^:]+):(.*)$")
				if key and value then -- Ensure a colon was found
					local normalized_key = vim.fn.trim(key):lower()
					local trimmed_value = vim.fn.trim(value)

					if normalized_key ~= "" then
						-- Handle potentially multi-value headers (e.g., Set-Cookie)
						-- If the key already exists, append to a list (or overwrite, common practice)
						-- For simplicity here, we overwrite (last value wins)
						-- To support multi-value, check if output.headers[normalized_key] exists
						-- if exists and type is string, convert to table {old_value, new_value}
						-- if exists and type is table, table.insert(existing_table, new_value)
						output.headers[normalized_key] = trimmed_value
					end
				else
					-- Line in header block doesn't look like a 'Key: Value' pair.
					-- Could be obsolete line folding, but we'll ignore it for simplicity.
					vim.notify(
						"Ignoring malformed line in header section: " .. line,
						vim.log.levels.DEBUG,
						{ title = "Request Parse" }
					)
				end
			end
		else
			-- Parsing Body: Add the line directly to preserve indentation etc.
			table.insert(body_lines, line)
		end
	end -- End loop through lines

	-- 4. Concatenate body lines
	output.body = table.concat(body_lines, "\n")

	-- 5. Process authorization header for automatic Basic Auth encoding
	output.headers = _process_auth_header(output.headers)

	-- 6. Return the parsed structure
	return output
end

--- Ensures a User-Agent header exists, adding a default if missing.
-- Assumes the input options table has a headers sub-table with LOWERCASE keys.
--
-- @param options (table) The parsed request options table, containing a `headers` sub-table.
-- @return (table) The options table, potentially modified with the default User-Agent.
function M.add_user_agent(options)
	-- 1. Basic sanity check for input structure
	if not options or type(options.headers) ~= "table" then
		vim.notify("Cannot add User-Agent: Invalid options structure.", vim.log.levels.WARN)
		return options -- Return unmodified or handle error appropriately
	end

	-- 2. Define the default User-Agent string
	--    Make this configurable if desired
	local default_user_agent = "hola.nvim/0.1" -- Example default

	-- 3. Check for the *lowercase* 'user-agent' key
	if options.headers["user-agent"] == nil then
		-- If the 'user-agent' header key does not exist...
		vim.notify("Adding default User-Agent header.", vim.log.levels.DEBUG, { title = "REST Client" })
		options.headers["user-agent"] = default_user_agent
	else
		-- If it already exists, do nothing. User provided one.
		vim.notify("User-Agent already provided by user.", vim.log.levels.DEBUG, { title = "REST Client" })
	end

	-- 4. Return the (potentially modified) options table
	return options
end

--- Parses raw response header strings into a key-value table.
-- Normalizes header keys to lowercase.
-- Handles multi-value headers by storing values as a list if a key appears multiple times.
--
-- @param response (table) The response object, expected to have a `headers` field
--                       which is a table (list) of raw "Key: Value" strings.
-- @return (table) The modified response object with an added `parsed_headers` field (table).
--                 Keys in `parsed_headers` are lowercase strings.
--                 Values are strings OR tables (lists) of strings for multi-value headers.
function M.parse_headers(response)
	-- 1. Initialize the parsed headers table within the response object
	response.parsed_headers = {}
	-- 2. Validate input: Ensure response.headers is a table (list)
	if type(response) ~= "table" or type(response.headers) ~= "table" then
		vim.notify(
			"Invalid input: response or response.headers is not a table.",
			vim.log.levels.WARN,
			{ title = "Header Parse Error" }
		)
		return response -- Return response object unmodified (with empty parsed_headers)
	end
	-- 3. Iterate through the raw header strings
	for _, header_line in ipairs(response.headers) do
		if type(header_line) ~= "string" then
			return
		end
		-- Split the line at the *first* colon encountered.
		local parts = vim.split(header_line, ":", { plain = true, max = 2 }) -- Split only once

		if #parts == 2 then
			-- Successfully split into potential key and value
			local key = trim(parts[1]) -- Trim whitespace from key
			local value = trim(parts[2]) -- Trim whitespace from value

			if key ~= "" then -- Ensure key is not empty after trimming
				local lower_key = key:lower() -- Normalize key to lowercase

				-- Handle multi-value headers (like Set-Cookie)
				local existing_value = response.parsed_headers[lower_key]

				if existing_value == nil then
					-- First time seeing this key, store value directly
					response.parsed_headers[lower_key] = value
				else
					-- Key already exists, handle collision
					if type(existing_value) == "table" then
						-- Already a list, append the new value
						table.insert(existing_value, value)
					else
						-- Was a single string, convert to a list containing old and new values
						response.parsed_headers[lower_key] = { existing_value, value }
					end
				end
			end -- End key not empty check
		else
			-- Line did not contain a colon, or was malformed? Ignore it.
			-- This might also include the initial HTTP status line if present in the list.
			-- Ignoring malformed header line
		end -- End split check
	end -- End loop
	return response
end

function M.detect_filetype(response)
	response.filetype = "unknown"

	-- 1. Handle bad input
	if type(response.parsed_headers) ~= "table" then
		return response
	end

	local content_type_header = response.parsed_headers["Content-Type"] or response.parsed_headers["content-type"]

	if type(content_type_header) ~= "string" then
		return response
	end

	-- 2. Extract the primary MIME type (part before the first ';')
	--    and convert to lowercase for case-insensitive comparison.
	--
	local mime_type = content_type_header:match("^%s*([^;]+)") -- Get content before ';' and trim leading space
	if not mime_type then
		mime_type = content_type_header -- Use the whole string if no ';' found
	end
	mime_type = mime_type:match("^%s*(.-)%s*$"):lower() -- Trim whitespace and make lowercase

	-- 3. Identify format based on the MIME type
	if mime_type == "application/json" or mime_type:find("+json$") then
		response.filetype = "json"
	elseif mime_type == "application/xml" or mime_type == "text/xml" or mime_type:find("+xml$") then
		response.filetype = "xml"
	elseif mime_type == "text/html" then
		response.filetype = "html"
	elseif mime_type == "text/plain" then
		response.filetype = "text"
	elseif mime_type == "application/x-www-form-urlencoded" or mime_type == "multipart/form-data" then
		-- Grouping both common form types under "form"
		response.filetype = "form"
	elseif mime_type == "application/octet-stream" then
		response.filetype = "binary"
	elseif mime_type:match("^application/.*javascript") then
		response.filetype = "javascript"
	end

	return response
end

return M
