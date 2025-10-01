local M = {}

local log_levels = {
	TRACE = 0,
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	OFF = 5,
}

local level_names = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF" }
for i, name in ipairs(level_names) do
	level_names[i - 1] = name
end

local current_level = log_levels.WARN
local max_log_size = 1024 * 1024 * 100
local file_size_warned = false

local function get_log_path()
	local log_dir = vim.fn.stdpath("log")
	return vim.fs.joinpath(log_dir, "hola.log")
end

local function ensure_log_directory()
	local log_path = get_log_path()
	local log_dir = vim.fn.fnamemodify(log_path, ":h")

	if vim.fn.isdirectory(log_dir) == 0 then
		vim.fn.mkdir(log_dir, "p")
	end
end

local function check_log_size()
	if file_size_warned then
		return
	end

	local log_path = M.get_filename()
	local stat = vim.loop.fs_stat(log_path)

	if stat and stat.size > max_log_size then
		file_size_warned = true
		vim.notify(
			string.format(
				"Hola log file is large (%d MB). Consider clearing it with :HolaLogClear",
				math.floor(stat.size / 1024 / 1024)
			),
			vim.log.levels.WARN
		)
	end
end

local function redact_sensitive_data(message)
	local redacted = message

	redacted = redacted:gsub("(Bearer%s+)([%w%-_]+)", function(prefix, token)
		if #token > 8 then
			return prefix .. token:sub(1, 4) .. "****" .. token:sub(-3)
		else
			return prefix .. "****"
		end
	end)

	redacted = redacted:gsub("(token[:%s=]+)([%w%-_]+)", function(prefix, token)
		if #token > 8 then
			return prefix .. token:sub(1, 4) .. "****" .. token:sub(-3)
		else
			return prefix .. "****"
		end
	end)

	redacted = redacted:gsub("(api[_-]?key[:%s=]+)([%w%-_]+)", function(prefix, key)
		if #key > 8 then
			return prefix .. key:sub(1, 4) .. "****" .. key:sub(-3)
		else
			return prefix .. "****"
		end
	end)

	redacted = redacted:gsub("(password[:%s=]+)([%w%-_!@#$%%^&*()]+)", function(prefix, pwd)
		return prefix .. "****"
	end)

	redacted = redacted:gsub("(sk%-[%w]+)", function(key)
		if #key > 8 then
			return key:sub(1, 7) .. "****" .. key:sub(-3)
		else
			return "sk-****"
		end
	end)

	redacted = redacted:gsub("(gho_[%w]+)", function(token)
		if #token > 8 then
			return token:sub(1, 7) .. "****" .. token:sub(-3)
		else
			return "gho_****"
		end
	end)

	return redacted
end

local function get_caller_info()
	local info = debug.getinfo(4, "Sl")
	if info then
		local file = info.short_src:match("([^/]+)$") or info.short_src
		local line = info.currentline or 0
		return string.format("[%s:%d]", file, line)
	end
	return "[unknown]"
end

local function format_timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

local function write_log(level, level_name, ...)
	if level < current_level then
		return
	end

	ensure_log_directory()

	local args = { ... }
	local message_parts = {}

	for _, arg in ipairs(args) do
		if type(arg) == "table" then
			table.insert(message_parts, vim.inspect(arg))
		else
			table.insert(message_parts, tostring(arg))
		end
	end

	local message = table.concat(message_parts, " ")
	message = redact_sensitive_data(message)

	local timestamp = format_timestamp()
	local caller = get_caller_info()
	local log_entry = string.format("[%s] [%s] %s %s\n", level_name, timestamp, caller, message)

	local log_path = M.get_filename()
	local file_handle = io.open(log_path, "a")

	if file_handle then
		file_handle:write(log_entry)
		file_handle:close()
		check_log_size()
	else
		vim.schedule(function()
			vim.notify("Failed to write to log file: " .. log_path, vim.log.levels.ERROR)
		end)
	end
end

function M.trace(...)
	write_log(log_levels.TRACE, "TRACE", ...)
end

function M.debug(...)
	write_log(log_levels.DEBUG, "DEBUG", ...)
end

function M.info(...)
	write_log(log_levels.INFO, "INFO", ...)
end

function M.warn(...)
	write_log(log_levels.WARN, "WARN", ...)
end

function M.error(...)
	write_log(log_levels.ERROR, "ERROR", ...)
end

function M.set_level(level)
	if type(level) == "string" then
		local upper_level = level:upper()
		if log_levels[upper_level] then
			current_level = log_levels[upper_level]
			M.info("Log level changed to", upper_level)
			return true
		else
			return false, "Invalid log level: " .. level
		end
	elseif type(level) == "number" then
		if level >= 0 and level <= log_levels.OFF then
			current_level = level
			M.info("Log level changed to", level_names[level])
			return true
		else
			return false, "Invalid log level number: " .. level
		end
	else
		return false, "Log level must be string or number"
	end
end

function M.get_level()
	return current_level
end

function M.get_level_name()
	return level_names[current_level]
end

function M.get_filename()
	return get_log_path()
end

function M.clear()
	local log_path = M.get_filename()
	local file_handle = io.open(log_path, "w")

	if file_handle then
		file_handle:close()
		file_size_warned = false
		M.info("Log file cleared")
		return true
	else
		return false, "Failed to clear log file: " .. log_path
	end
end

function M.redact(message)
	return redact_sensitive_data(message)
end

M.levels = log_levels

return M
