local M = {}

--- Default configuration for JSON formatting
local DEFAULT_CONFIG = {
	indent_size = 2,
	sort_keys = true, -- Sort keys by default for consistent output
	compact_arrays = true, -- Keep simple arrays on one line
	max_array_length = 5, -- Max items before expanding array
}

--- Creates indentation string for the given level
-- @param level (number) Indentation level
-- @param indent_size (number) Number of spaces per level
-- @return (string) Indentation string
local function create_indent(level, indent_size)
	return string.rep(" ", level * indent_size)
end

--- Checks if a table represents a simple array (only primitive values)
-- @param tbl (table) Table to check
-- @return (boolean) True if array contains only primitives
local function is_simple_array(tbl)
	for _, value in ipairs(tbl) do
		local value_type = type(value)
		if value_type == "table" then
			return false
		end
	end
	return true
end

--- Formats a JSON value recursively
-- @param value (any) The value to format
-- @param level (number) Current indentation level
-- @param config (table) Formatting configuration
-- @return (string) Formatted JSON string
local function format_value(value, level, config)
	local value_type = type(value)
	local indent = create_indent(level, config.indent_size)
	local next_indent = create_indent(level + 1, config.indent_size)

	if value_type == "nil" or value == vim.NIL then
		return "null"
	elseif value_type == "boolean" then
		return tostring(value)
	elseif value_type == "number" then
		return tostring(value)
	elseif value_type == "string" then
		-- Escape special characters
		local escaped = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
		return '"' .. escaped .. '"'
	elseif value_type == "table" then
		-- Handle vim.empty_dict() explicitly as object
		-- Check if it's vim.empty_dict() by its string representation
		if tostring(value) == "vim.empty_dict()" then
			return "{}"
		end

		-- Determine if it's an array or object
		local is_array = true
		local max_index = 0
		local count = 0

		for k, _ in pairs(value) do
			count = count + 1
			if type(k) ~= "number" or k <= 0 or k ~= math.floor(k) then
				is_array = false
				break
			end
			max_index = math.max(max_index, k)
		end

		-- Check for sparse array
		if is_array and count ~= max_index then
			is_array = false
		end

		if is_array then
			-- Format as array
			if #value == 0 then
				return "[]"
			end

			-- Check if we should format compactly
			if config.compact_arrays and #value <= config.max_array_length and is_simple_array(value) then
				local items = {}
				for i = 1, #value do
					table.insert(items, format_value(value[i], 0, config))
				end
				return "[" .. table.concat(items, ", ") .. "]"
			else
				-- Multi-line array
				local items = {}
				for i = 1, #value do
					table.insert(items, next_indent .. format_value(value[i], level + 1, config))
				end
				return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
			end
		else
			-- Format as object
			local keys = {}
			for k, _ in pairs(value) do
				table.insert(keys, k)
			end

			if #keys == 0 then
				return "{}"
			end

			-- Always sort keys for consistent output unless explicitly disabled
			if config.sort_keys ~= false then
				table.sort(keys)
			end

			local items = {}
			for _, key in ipairs(keys) do
				local formatted_key = format_value(key, 0, config)
				local formatted_value = format_value(value[key], level + 1, config)
				table.insert(items, next_indent .. formatted_key .. ": " .. formatted_value)
			end

			return "{\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "}"
		end
	else
		-- Fallback for unknown types
		return '"<' .. value_type .. '>"'
	end
end

--- Formats JSON string with pretty printing
-- @param json_string (string) Raw JSON string to format
-- @param options (table|nil) Optional formatting configuration
-- @return (string|nil, string|nil) Formatted JSON or nil, error message if failed
function M.format(json_string, options)
	if not json_string or json_string == "" then
		return nil, "Empty JSON string"
	end

	-- Merge options with defaults
	local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, options or {})

	-- Parse JSON using Neovim's built-in function
	local ok, parsed = pcall(vim.fn.json_decode, json_string)
	if not ok then
		return nil, "Invalid JSON: " .. tostring(parsed)
	end

	-- Format the parsed data
	local formatted = format_value(parsed, 0, config)
	return formatted, nil
end

--- Minifies JSON by removing unnecessary whitespace
-- @param json_string (string) JSON string to minify
-- @return (string|nil, string|nil) Minified JSON or nil, error message if failed
function M.minify(json_string)
	if not json_string or json_string == "" then
		return nil, "Empty JSON string"
	end

	-- Parse JSON first
	local ok, parsed = pcall(vim.fn.json_decode, json_string)
	if not ok then
		return nil, "Invalid JSON: " .. tostring(parsed)
	end

	-- Format with minimal configuration
	local minified = format_value(parsed, 0, {
		indent_size = 0,
		sort_keys = true,
		compact_arrays = true,
		max_array_length = 999999,
	})

	-- Remove all newlines and extra spaces for true minification
	minified = minified:gsub("\n", ""):gsub("%s+", "")
	-- Fix spacing around colons and commas for proper JSON
	minified = minified:gsub("}%s*,", "},"):gsub("]%s*,", "],"):gsub(":%s*", ":"):gsub(",%s*", ",")

	return minified, nil
end

--- Gets default configuration
-- @return (table) Default configuration table
function M.get_default_config()
	return vim.deepcopy(DEFAULT_CONFIG)
end

return M

