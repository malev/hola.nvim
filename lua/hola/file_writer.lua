local M = {}

--- Ensures the parent directory exists for a given file path.
-- Creates all necessary parent directories if they don't exist.
-- @param file_path (string) The file path for which to ensure parent directory exists.
-- @return (boolean, string|nil) True if directory exists/was created, false and error message otherwise.
local function _ensure_parent_directory(file_path)
	-- Get the parent directory
	local parent_dir = vim.fn.fnamemodify(file_path, ":h")

	-- Check if parent directory exists
	if vim.fn.isdirectory(parent_dir) == 0 then
		-- Try to create the directory and all parents
		local result = vim.fn.mkdir(parent_dir, "p")
		if result == 0 then
			return false, "Failed to create directory: " .. parent_dir
		end
	end

	return true
end

--- Writes binary or text content to a file.
-- Creates parent directories if they don't exist.
-- Handles both relative and absolute paths.
-- @param file_path (string) The path where to save the file.
-- @param content (string) The content to write to the file.
-- @return (boolean, string|nil) True if successful, false and error message otherwise.
function M.write_file(file_path, content)
	-- Validate inputs
	if not file_path or file_path == "" then
		return false, "File path cannot be empty"
	end

	if not content then
		content = ""
	end

	-- Expand the file path (handle ~, ., .., etc.)
	local expanded_path = vim.fn.expand(file_path)

	-- Ensure parent directory exists
	local dir_ok, dir_err = _ensure_parent_directory(expanded_path)
	if not dir_ok then
		return false, dir_err
	end

	-- Write the file using Lua's io library (handles binary content)
	local file, err = io.open(expanded_path, "wb")
	if not file then
		return false, "Failed to open file for writing: " .. (err or "unknown error")
	end

	local write_ok, write_err = file:write(content)
	if not write_ok then
		file:close()
		return false, "Failed to write to file: " .. (write_err or "unknown error")
	end

	file:close()

	return true, expanded_path
end

--- Saves an HTTP response to a file.
-- Extracts the body from the response and writes it to the specified file.
-- @param response (table) The response object containing the body field.
-- @param file_path (string) The path where to save the response.
-- @return (boolean, string|nil) True and actual file path if successful, false and error message otherwise.
function M.save_response(response, file_path)
	-- Validate response
	if not response or type(response) ~= "table" then
		return false, "Invalid response object"
	end

	-- Get the response body
	local body = response.body or ""

	-- Write to file
	local ok, result = M.write_file(file_path, body)

	return ok, result
end

return M
