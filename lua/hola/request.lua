local curl = require("plenary.curl")

local M = {}

local function compile_template(str)
	return str:gsub("{{([^}]+)}}", function(var_name)
		local env_value = vim.env[var_name]
		if env_value then
			return env_value
		else
			vim.notify("Environment variable not found: " .. var_name, vim.log.warning)
			return ""
		end
	end)
end

--- Removes lines that consist entirely of comments.
-- A comment line starts with '#', potentially preceded by whitespace.
-- Preserves blank lines and lines that have non-comment content.
-- @param str (string) The input multi-line string.
-- @return (string) The string with comment-only lines removed.
local function remove_comments(str)
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

--- Parses the request text block into its components.
-- Expects the first line to be METHOD URL [HTTP/Version].
-- Headers are key:value pairs.
-- A blank line separates headers from the body.
-- Normalizes header keys to lowercase.
--
-- @param content (string) The request text block (multiline).
-- @return (table|nil) A table with keys {method, path, http_version, headers, body} on success,
--                     or nil if the request line is fundamentally invalid.
local function parse(content)
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

	-- 5. Return the parsed structure
	return output
end

--- Ensures a User-Agent header exists, adding a default if missing.
-- Assumes the input options table has a headers sub-table with LOWERCASE keys.
--
-- @param options (table) The parsed request options table, containing a `headers` sub-table.
-- @return (table) The options table, potentially modified with the default User-Agent.
local function add_user_agent(options)
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

local function compose(...)
	local functions = { ... }
	return function(initial_value)
		local result = initial_value
		for i = 1, #functions do
			result = functions[i](result)
		end
		return result
	end
end

local function send_request(options)
	local start_time = vim.loop.now()

	local results = curl.request({
		url = options.path,
		method = options.method,
		body = options.body,
		headers = options.headers,
	})

	local end_time = vim.loop.now()
	local execution_time = end_time - start_time
	results["elapsed"] = execution_time

	return results
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
local function parse_headers(response)
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
		if type(header_line) == "string" then
			-- Split the line at the *first* colon encountered.
			local parts = vim.split(header_line, ":", { plain = true, max = 2 }) -- Split only once

			if #parts == 2 then
				-- Successfully split into potential key and value
				local key = vim.fn.trim(parts[1]) -- Trim whitespace from key
				local value = vim.fn.trim(parts[2]) -- Trim whitespace from value

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
				vim.notify(
					"Ignoring malformed header line or status line: " .. header_line,
					vim.log.levels.DEBUG,
					{ title = "Header Parse" }
				)
			end -- End split check
		end -- End type check
	end -- End loop
	return response
end

local function detect_filetype(response)
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

function M.process(str)
	return compose(
		remove_comments,
		compile_template,
		parse,
		add_user_agent,
		send_request,
		parse_headers,
		detect_filetype
	)(str)
end

if _TESTING then
	M.add_user_agent = add_user_agent
	M.detect_filetype = detect_filetype
	M.parse = parse
	M.parse_headers = parse_headers
	M.remove_comments = remove_comments
end

return M
