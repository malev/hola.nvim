local M = {}
local providers = require("hola.providers")

--- Checks for a valid `.provider` file in the current working directory.
---
--- @return (string | nil) The absolute path to the `.provider` file if found and valid,
---                       otherwise nil (issues a warning if not found).
local function find_provider_file_in_cwd()
	-- 1. Get Current Working Directory
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		vim.notify("Could not determine current working directory.", vim.log.levels.ERROR, { title = "Provider File" })
		return nil
	end

	-- 2. Construct the potential path
	local provider_path = cwd .. "/.provider"

	-- 3. Check if the path points to a valid, regular file
	local stat = vim.loop.fs_stat(provider_path)
	if not stat or stat.type ~= "file" then
		-- File does not exist or is not a regular file
		vim.notify("No .provider file found in current directory: " .. cwd, vim.log.levels.DEBUG, { title = "Provider File" })
		return nil -- Indicate not found or invalid
	end

	-- 4. File exists and is a regular file, return its path
	vim.notify("Found .provider file at: " .. provider_path, vim.log.levels.DEBUG, { title = "Provider File" })
	return provider_path
end

--- Reads and parses a .provider file from the given path.
-- Handles KEY=provider:path:field syntax, comments (#), and blank lines.
-- Resolves provider secrets at parse time.
--
-- @param filepath (string) The full path to the .provider file.
-- @return (table | nil) A table containing the resolved provider variables,
--                       or nil if the file cannot be read or is empty after parsing.
-- @return (table) A table containing any errors encountered during resolution.
local function parse_provider_file(filepath)
	-- 1. Attempt to read the file content
	local ok, lines_or_err = pcall(vim.fn.readfile, filepath)
	if not ok or type(lines_or_err) ~= "table" then
		vim.notify(
			"Error reading .provider file: " .. filepath .. " (" .. tostring(lines_or_err) .. ")",
			vim.log.levels.ERROR,
			{ title = "Provider File" }
		)
		return nil, {} -- Indicate failure to read/load
	end

	-- 2. Parse the loaded lines
	local provider_vars = {}
	local errors = {}
	local file_content = lines_or_err

	for line_num, line in ipairs(file_content) do
		local trimmed_line = vim.fn.trim(line)
		-- Skip blank lines and comments
		if trimmed_line ~= "" and not trimmed_line:match("^#") then
			-- Match KEY=VALUE
			local key, value = trimmed_line:match("^([^=]+)=(.*)$")
			if key then
				local trimmed_key = vim.fn.trim(key)
				local trimmed_value = vim.fn.trim(value)

				if trimmed_key ~= "" then -- Avoid empty keys
					-- Parse the provider reference
					local parsed = providers.parse_variable_reference(trimmed_value)

					if parsed.type == "provider" then
						-- Check if provider is available
						if not providers.is_provider_available(parsed.provider) then
							table.insert(errors, {
								line = line_num,
								key = trimmed_key,
								error = "Provider '" .. parsed.provider .. "' is not available or enabled"
							})
						else
							-- Resolve the secret
							local secret_value, error = providers.resolve_provider_secret(parsed.provider, parsed.path, parsed.field)
							if secret_value then
								provider_vars[trimmed_key] = secret_value
								vim.notify(
									"Resolved provider secret: " .. trimmed_key,
									vim.log.levels.DEBUG,
									{ title = "Provider File" }
								)
							else
								table.insert(errors, {
									line = line_num,
									key = trimmed_key,
									error = error or "Failed to resolve provider secret"
								})
							end
						end
					else
						-- Not a provider reference, treat as regular value
						provider_vars[trimmed_key] = trimmed_value
						vim.notify(
							"Added static value: " .. trimmed_key,
							vim.log.levels.DEBUG,
							{ title = "Provider File" }
						)
					end
				end
			else
				vim.notify(
					"Ignoring malformed line " .. line_num .. " in .provider file: " .. line,
					vim.log.levels.DEBUG,
					{ title = "Provider File" }
				)
			end
		end
	end

	-- 3. Report results
	local var_count = 0
	for _ in pairs(provider_vars) do
		var_count = var_count + 1
	end

	if var_count == 0 and #errors == 0 then
		vim.notify("No variables found or parsed in: " .. filepath, vim.log.levels.INFO, { title = "Provider File" })
	else
		local message = "Loaded " .. var_count .. " variables from " .. filepath
		if #errors > 0 then
			message = message .. " (" .. #errors .. " errors)"
		end
		vim.notify(message, vim.log.levels.INFO, { title = "Provider File" })
	end

	-- 4. Return the resolved variables and any errors
	return provider_vars, errors
end

--- Load provider variables from .provider file
--- @return table, table provider_variables, errors
function M.load()
	local file = find_provider_file_in_cwd()
	if file then
		return parse_provider_file(file)
	end

	return {}, {}
end

-- Expose internal functions for testing
M.find_provider_file_in_cwd = find_provider_file_in_cwd
M.parse_provider_file = parse_provider_file

return M