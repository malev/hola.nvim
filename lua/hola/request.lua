local curl = require("plenary.curl")

local M = {}

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

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

local function remove_comments(str)
	local result = ""
	local foundNonHash = false
	local start = 1
	local finish = 1

	if not string.sub(str, -1, -1) == "\n" then
		str = str .. "\n"
	end

	while true do
		finish = str:find("\n", start)
		if not finish then
			-- Last line, or a single line string.
			local line = str:sub(start)
			if not foundNonHash and line:sub(1, 1) == "#" then
			-- Skip
			else
				result = result .. line
			end
			break
		end

		local line = str:sub(start, finish - 1)
		if not foundNonHash and line:sub(1, 1) == "#" then
		-- Skip
		else
			foundNonHash = true
			result = result .. line .. "\n"
		end

		start = finish + 1
	end

	return result
end

local function parse(content)
	local output = {
		headers = {},
		body = "",
		path = "",
		http_version = "",
		method = "",
	}
	local temp = {}
	local headers = {}
	local header_parsing = true
	local lines = vim.split(content, "\n")

	for i, line in ipairs(lines) do
		if i == 1 then
			local parts = vim.split(line, "%s+") -- Split by whitespace
			output["method"] = parts[1]
			output["path"] = parts[2]
			output["http_version"] = parts[3]
		elseif line == "" then
			header_parsing = false
		elseif header_parsing then
			local parts = vim.split(line, ":%s+", { trimempty = true }) -- Split by colon, trim whitespace
			if #parts == 2 then
				headers[parts[1]] = parts[2]
			end
		else
			table.insert(temp, line)
		end
	end

	output["body"] = table.concat(temp, "\n")
	output["headers"] = headers

	return output
end

local function add_user_agent(opts)
	if opts.headers["user-agent"] == nil then
		opts.headers["user-agent"] = "hola.nvim/0.1"
	end
	return opts
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

local function parse_headers(response)
	response.parsed_headers = {}

	if type(response.headers) ~= "table" then
		return response
	end

	for _, item in ipairs(response.headers) do
		local key, value = item:match("([^:]+):(.*)")
		if key and value then
			response.parsed_headers[key] = trim(value)
		end
	end

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
	M.parse_headers = parse_headers
	M.remove_comments = remove_comments
end

return M
