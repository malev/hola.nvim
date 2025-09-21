local M = {}

--- Checks for a valid `.env` file in the current working directory.
--
-- @return (string | nil) The absolute path to the `.env` file if found and valid,
--                       otherwise nil (issues a warning if not found).
local function find_dotenv_in_cwd()
	-- 1. Get Current Working Directory
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		vim.notify("Could not determine current working directory.", vim.log.levels.ERROR, { title = "DotEnv" })
		return nil
	end

	-- 2. Construct the potential path
	local dotenv_path = cwd .. "/.env"

	-- 3. Check if the path points to a valid, regular file
	local stat = vim.loop.fs_stat(dotenv_path)
	if not stat or stat.type ~= "file" then
		-- File does not exist or is not a regular file
		vim.notify("No .env file found in current directory: " .. cwd, vim.log.levels.DEBUG, { title = "DotEnv" })
		return nil -- Indicate not found or invalid
	end

	-- 4. File exists and is a regular file, return its path
	vim.notify("Found .env file at: " .. dotenv_path, vim.log.levels.DEBUG, { title = "DotEnv" })
	return dotenv_path
end

--- Reads and parses a .env file from the given path.
-- Handles basic KEY=VALUE syntax, comments (#), and blank lines.
-- Trims whitespace from keys and values. Does not handle complex quoting or variable expansion.
--
-- @param filepath (string) The full path to the .env file.
-- @return (table | nil) A table containing the loaded environment variables,
--                       or nil if the file cannot be read or is empty after parsing.
local function parse_dotenv_file(filepath)
	-- 1. Attempt to read the file content
	local ok, lines_or_err = pcall(vim.fn.readfile, filepath)
	if not ok or type(lines_or_err) ~= "table" then
		vim.notify(
			"Error reading .env file: " .. filepath .. " (" .. tostring(lines_or_err) .. ")",
			vim.log.levels.ERROR,
			{ title = "DotEnv" }
		)
		return nil -- Indicate failure to read/load
	end

	-- 2. Parse the loaded lines
	local env_vars = {}
	local file_content = lines_or_err
	for _, line in ipairs(file_content) do
		local trimmed_line = vim.fn.trim(line)
		-- Skip blank lines and comments
		if trimmed_line ~= "" and not trimmed_line:match("^#") then
			-- Match KEY=VALUE
			local key, value = trimmed_line:match("^([^=]+)=(.*)$")
			if key then
				local trimmed_key = vim.fn.trim(key)
				local trimmed_value = vim.fn.trim(value)
				if trimmed_key ~= "" then -- Avoid empty keys
					env_vars[trimmed_key] = trimmed_value
				end
			else
				vim.notify("Ignoring malformed line in .env file: " .. line, vim.log.levels.DEBUG, { title = "DotEnv" })
			end
		end
	end

	-- 3. Check if any variables were actually loaded
	local var_count = 0
	for _ in pairs(env_vars) do
		var_count = var_count + 1
	end

	if var_count == 0 then
		vim.notify("No variables found or parsed in: " .. filepath, vim.log.levels.INFO, { title = "DotEnv" })
		-- Decide if an empty file should return nil or {}. Returning {} is usually safer.
		-- return nil
	else
		vim.notify("Parsed " .. var_count .. " variables from " .. filepath, vim.log.levels.INFO, { title = "DotEnv" })
	end

	-- 4. Return the parsed variables
	return env_vars
end

function M.load()
	local file = find_dotenv_in_cwd()
	if file then
		return parse_dotenv_file(file)
	end

	return {}
end

if _TESTING then
	M.find_dotenv_in_cwd = find_dotenv_in_cwd
	M.parse_dotenv_file = parse_dotenv_file
end

return M
