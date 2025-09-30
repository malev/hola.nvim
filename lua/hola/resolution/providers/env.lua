--- Environment Variable Provider
--- Handles resolution of environment variables from .env files and OS environment
--- Supports both traditional {{VAR_NAME}} and explicit {{env:VAR_NAME}} formats

local BaseProvider = require("hola.resolution.base_provider")
local config = require("hola.resolution.config")

local EnvProvider = setmetatable({}, { __index = BaseProvider })
EnvProvider.__index = EnvProvider

--- Create a new environment variable provider instance
--- @return table provider New provider instance
function EnvProvider.new()
	local self = setmetatable({}, EnvProvider)

	-- Provider metadata
	self.name = "env"
	self.description = "Environment variables from .env files and OS environment"
	self.config_files = { ".env" }
	self.requires_network = false

	-- Provider-specific state
	self._dotenv_data = {}
	self._dotenv_loaded = false
	self._dotenv_file_path = nil
	self._dotenv_file_mtime = nil

	return self
end

--- Check if this provider can handle a given variable
--- @param variable string Full variable like "{{provider:identifier}}"
--- @return boolean True if this provider handles this pattern
function EnvProvider:can_handle(variable)
	-- Handle explicit env provider format only: {{env:VAR_NAME}}
	return variable:match("^{{env:.+}}$") ~= nil
end

--- Find .env file in the current working directory
--- @return string|nil filepath Path to .env file or nil if not found
local function find_dotenv_file()
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		return nil
	end

	local dotenv_path = cwd .. "/.env"
	local stat = vim.loop.fs_stat(dotenv_path)

	if stat and stat.type == "file" then
		return dotenv_path
	end

	return nil
end

--- Parse .env file content
--- @param filepath string Path to .env file
--- @return table|nil env_vars Parsed environment variables or nil on error
local function parse_dotenv_file(filepath)
	local ok, lines_or_err = pcall(vim.fn.readfile, filepath)
	if not ok or type(lines_or_err) ~= "table" then
		return nil
	end

	local env_vars = {}
	for _, line in ipairs(lines_or_err) do
		local trimmed_line = vim.fn.trim(line)

		-- Skip blank lines and comments
		if trimmed_line ~= "" and not trimmed_line:match("^#") then
			-- Match KEY=VALUE
			local key, value = trimmed_line:match("^([^=]+)=(.*)$")
			if key then
				local trimmed_key = vim.fn.trim(key)
				local trimmed_value = vim.fn.trim(value)

				-- Remove surrounding quotes if present
				if trimmed_value:match('^".*"$') then
					trimmed_value = trimmed_value:sub(2, -2)
				elseif trimmed_value:match("^'.*'$") then
					trimmed_value = trimmed_value:sub(2, -2)
				end

				if trimmed_key ~= "" then
					env_vars[trimmed_key] = trimmed_value
				end
			end
		end
	end

	return env_vars
end

--- Load or reload .env file if needed
--- @return boolean success True if .env file was loaded successfully or doesn't exist
function EnvProvider:_load_dotenv()
	local dotenv_path = find_dotenv_file()

	if not dotenv_path then
		-- No .env file found, that's okay
		self._dotenv_data = {}
		self._dotenv_loaded = true
		self._dotenv_file_path = nil
		self._dotenv_file_mtime = nil
		return true
	end

	-- Check if we need to reload the file
	local stat = vim.loop.fs_stat(dotenv_path)
	if not stat then
		return false
	end

	local current_mtime = stat.mtime.sec

	if self._dotenv_loaded and self._dotenv_file_path == dotenv_path and self._dotenv_file_mtime == current_mtime then
		-- File hasn't changed, use cached data
		return true
	end

	-- Load/reload the file
	local env_vars = parse_dotenv_file(dotenv_path)
	if not env_vars then
		return false
	end

	self._dotenv_data = env_vars
	self._dotenv_loaded = true
	self._dotenv_file_path = dotenv_path
	self._dotenv_file_mtime = current_mtime

	return true
end

--- Load and validate provider-specific configuration
--- @return boolean success True if config loaded successfully
--- @return string|nil error Error message if config loading failed
function EnvProvider:load_config()
	local provider_config = config.get_provider_config(self.name)

	-- Set defaults and validate configuration
	self._config = {
		cache_ttl = provider_config.cache_ttl or 300, -- 5 minutes default
		reload_on_change = provider_config.reload_on_change ~= false, -- Default true
		fallback_to_os = provider_config.fallback_to_os ~= false, -- Default true
		case_sensitive = provider_config.case_sensitive ~= false, -- Default true
	}

	return true, nil
end

--- Initialize the provider
--- @return boolean success True if initialization successful
--- @return string|nil error Error message if initialization failed
function EnvProvider:initialize()
	if self._initialized then
		return true, nil
	end

	-- Load configuration first
	local config_success, config_error = self:load_config()
	if not config_success then
		return false, config_error
	end

	-- Load .env file
	local dotenv_success = self:_load_dotenv()
	if not dotenv_success then
		return false, "Failed to load .env file"
	end

	self._initialized = true
	self._authenticated = true -- No authentication needed for env vars

	return true, nil
end

--- Resolve environment variable to its value
--- @param identifier string The variable name (without {{}} braces)
--- @return string|nil value The resolved value or nil if not found
--- @return string|nil error Error message if resolution failed
function EnvProvider:resolve(identifier)
	-- Ensure we're initialized
	if not self._initialized then
		local success, error = self:initialize()
		if not success then
			return nil, error
		end
	end

	-- Extract variable name from identifier
	local var_name = identifier

	-- Handle explicit env: prefix
	if identifier:match("^env:") then
		var_name = identifier:sub(5) -- Remove "env:" prefix
	end

	-- Validate variable name
	if not var_name or var_name == "" then
		return nil, "Empty variable name"
	end

	-- Check cache first
	local cache_key = "env:" .. var_name
	local cached_value = self:cache_get(cache_key)
	if cached_value then
		return cached_value, nil
	end

	-- Reload .env file if configured to do so
	if self._config.reload_on_change then
		self:_load_dotenv()
	end

	local value = nil

	-- 1. Check .env file first (higher precedence)
	if self._dotenv_data[var_name] then
		value = self._dotenv_data[var_name]
	end

	-- 2. Fall back to OS environment if not found in .env
	if not value and self._config.fallback_to_os then
		value = os.getenv(var_name)
	end

	-- 3. Try case-insensitive search if enabled and not found
	if not value and not self._config.case_sensitive then
		local lower_var_name = var_name:lower()

		-- Search .env data case-insensitively
		for key, val in pairs(self._dotenv_data) do
			if key:lower() == lower_var_name then
				value = val
				break
			end
		end

		-- Search OS environment case-insensitively (more complex)
		if not value and self._config.fallback_to_os then
			-- Note: This is platform-dependent and may not work on all systems
			-- On Unix-like systems, environment variables are typically case-sensitive
			-- This is more of a fallback attempt
			for key, val in pairs(vim.env) do
				if key:lower() == lower_var_name then
					value = val
					break
				end
			end
		end
	end

	if value then
		-- Cache the result
		self:cache_set(cache_key, value, self._config.cache_ttl)
		return value, nil
	else
		return nil, "Environment variable '" .. var_name .. "' not found"
	end
end

--- Get provider-specific metadata
--- @return table metadata Extended metadata with env-specific info
function EnvProvider:get_metadata()
	local base_metadata = BaseProvider.get_metadata(self)

	-- Add env-specific metadata
	base_metadata.dotenv_loaded = self._dotenv_loaded
	base_metadata.dotenv_file_path = self._dotenv_file_path
	base_metadata.dotenv_variables = self._dotenv_data and vim.tbl_count(self._dotenv_data) or 0
	base_metadata.cache_stats = self:cache_stats()

	return base_metadata
end

--- Clean up provider resources
function EnvProvider:cleanup()
	BaseProvider.cleanup(self)

	self._dotenv_data = {}
	self._dotenv_loaded = false
	self._dotenv_file_path = nil
	self._dotenv_file_mtime = nil
end

return EnvProvider
