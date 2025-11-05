local M = {}

--- Parses a GraphQL request block into query and variables
-- Expected format:
--   GRAPHQL url
--   [headers]
--
--   query/mutation text
--
--   [optional JSON variables]
--
-- @param content (string) The raw GraphQL request text
-- @return (table|nil) {query = string, variables = table|nil} or nil on error
function M.parse_graphql_body(content)
	if not content or vim.fn.trim(content) == "" then
		return { query = "", variables = nil }
	end

	local lines = vim.split(content, "\n")
	local query_lines = {}
	local variables_lines = {}
	local in_variables = false
	local found_blank_after_query = false

	for _, line in ipairs(lines) do
		local trimmed = vim.fn.trim(line)

		if in_variables then
			-- Collecting variables JSON
			table.insert(variables_lines, line)
		elseif found_blank_after_query and trimmed ~= "" then
			-- First non-blank line after query block starts variables
			in_variables = true
			table.insert(variables_lines, line)
		elseif trimmed == "" and #query_lines > 0 then
			-- Blank line after query content
			found_blank_after_query = true
		elseif trimmed ~= "" then
			-- Query content
			table.insert(query_lines, line)
		end
	end

	-- Build the query string
	local query = table.concat(query_lines, "\n")
	query = vim.fn.trim(query)

	if query == "" then
		vim.notify("GraphQL query cannot be empty", vim.log.levels.ERROR)
		return nil
	end

	-- Parse variables if present
	local variables = nil
	if #variables_lines > 0 then
		local variables_json = table.concat(variables_lines, "\n")
		variables_json = vim.fn.trim(variables_json)

		if variables_json ~= "" then
			local ok, parsed = pcall(vim.fn.json_decode, variables_json)
			if not ok then
				vim.notify(
					"Invalid JSON in GraphQL variables section: " .. tostring(parsed),
					vim.log.levels.ERROR
				)
				return nil
			end
			variables = parsed
		end
	end

	return {
		query = query,
		variables = variables,
	}
end

--- Transforms a GraphQL request into a standard HTTP POST request
-- @param parsed_request (table) Request from utils.parse_request with method="GRAPHQL"
-- @return (table) Modified request with method="POST" and JSON body
function M.transform_to_http(parsed_request)
	if not parsed_request or parsed_request.method ~= "GRAPHQL" then
		return parsed_request
	end

	-- Parse the GraphQL body
	local graphql_data = M.parse_graphql_body(parsed_request.body)
	if not graphql_data then
		return nil
	end

	-- Create the GraphQL request body
	local body_table = {
		query = graphql_data.query,
	}

	if graphql_data.variables then
		body_table.variables = graphql_data.variables
	end

	-- Convert to JSON
	local ok, json_body = pcall(vim.fn.json_encode, body_table)
	if not ok then
		vim.notify("Failed to encode GraphQL request: " .. tostring(json_body), vim.log.levels.ERROR)
		return nil
	end

	-- Transform the request
	parsed_request.method = "POST"
	parsed_request.body = json_body

	-- Ensure Content-Type is set
	if not parsed_request.headers["content-type"] then
		parsed_request.headers["content-type"] = "application/json"
	end

	return parsed_request
end

--- Formats GraphQL response to highlight errors if present
-- @param response (table) Response object with body
-- @return (table) Response object, potentially with modified body
function M.format_response(response)
	if not response or not response.body or response.filetype ~= "json" then
		return response
	end

	-- Try to parse the response
	local ok, parsed = pcall(vim.fn.json_decode, response.body)
	if not ok then
		return response
	end

	-- Check if it's a GraphQL response (has data or errors field)
	if type(parsed) == "table" and (parsed.data ~= nil or parsed.errors ~= nil) then
		response.is_graphql = true

		-- Add error summary if errors are present
		if parsed.errors and type(parsed.errors) == "table" and #parsed.errors > 0 then
			response.graphql_errors = parsed.errors
		end
	end

	return response
end

--- Checks if a string looks like a GraphQL query or mutation
-- @param text (string) Text to check
-- @return (boolean) True if text appears to be GraphQL
function M.is_graphql_query(text)
	if not text or text == "" then
		return false
	end

	local trimmed = vim.fn.trim(text)

	-- Check for common GraphQL keywords
	return trimmed:match("^%s*query%s+")
		or trimmed:match("^%s*mutation%s+")
		or trimmed:match("^%s*subscription%s+")
		or trimmed:match("^%s*query%s*{")
		or trimmed:match("^%s*mutation%s*{")
		or trimmed:match("^%s*{%s*[%w_]+%s*%(")  -- Shorthand query syntax
		or trimmed:match("^%s*{%s*[%w_]+%s*{")   -- Simple query
end

--- Validates a GraphQL query syntax (basic validation)
-- @param query (string) GraphQL query text
-- @return (boolean, string|nil) True if valid, or false with error message
function M.validate_query(query)
	if not query or vim.fn.trim(query) == "" then
		return false, "Query cannot be empty"
	end

	-- Basic bracket matching
	local open_braces = 0
	local open_parens = 0
	local in_string = false
	local escape_next = false

	for i = 1, #query do
		local char = query:sub(i, i)

		if escape_next then
			escape_next = false
		elseif char == "\\" then
			escape_next = true
		elseif char == '"' then
			in_string = not in_string
		elseif not in_string then
			if char == "{" then
				open_braces = open_braces + 1
			elseif char == "}" then
				open_braces = open_braces - 1
			elseif char == "(" then
				open_parens = open_parens + 1
			elseif char == ")" then
				open_parens = open_parens - 1
			end
		end
	end

	if open_braces ~= 0 then
		return false, "Mismatched braces in GraphQL query"
	end

	if open_parens ~= 0 then
		return false, "Mismatched parentheses in GraphQL query"
	end

	if in_string then
		return false, "Unclosed string in GraphQL query"
	end

	-- Check for basic GraphQL structure
	if not M.is_graphql_query(query) then
		return false, "Does not appear to be a valid GraphQL query/mutation"
	end

	return true, nil
end

return M
