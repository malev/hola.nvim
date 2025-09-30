--- References Provider
--- Handles resolution of variable aliases and shortcuts to other providers
--- Supports {{refs:VARIABLE_NAME}} format with mappings defined in 'refs' file

local BaseProvider = require("hola.resolution.base_provider")
local config = require("hola.resolution.config")

local RefsProvider = setmetatable({}, { __index = BaseProvider })
RefsProvider.__index = RefsProvider

--- Create a new references provider instance
--- @return table provider New provider instance
function RefsProvider.new()
	local self = setmetatable({}, RefsProvider)

	-- Provider metadata
	self.name = "refs"
	self.description = "Variable aliases and shortcuts to other providers"
	self.config_files = { "refs" }
	self.requires_network = false

	-- Provider-specific state
	self._refs_data = {}
	self._refs_loaded = false
	self._refs_file_path = nil
	self._refs_file_mtime = nil

	return self
end

--- Check if this provider can handle a given variable
--- @param variable string Full variable like "{{provider:identifier}}"
--- @return boolean True if this provider handles this pattern
function RefsProvider:can_handle(variable)
	-- Handle explicit refs provider format only: {{refs:VARIABLE_NAME}}
	return variable:match("^{{refs:.+}}$") ~= nil
end

--- Find refs file in the current working directory
--- @return string|nil filepath Path to refs file or nil if not found
local function find_refs_file()
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		return nil
	end

	local refs_path = cwd .. "/refs"
	local stat = vim.loop.fs_stat(refs_path)

	if stat and stat.type == "file" then
		return refs_path
	end

	return nil
end

--- Parse refs file content
--- @param filepath string Path to refs file
--- @return table|nil refs_data Parsed reference mappings or nil on error
local function parse_refs_file(filepath)
	local ok, lines_or_err = pcall(vim.fn.readfile, filepath)
	if not ok or type(lines_or_err) ~= "table" then
		return nil
	end

	local refs_data = {}
	for _, line in ipairs(lines_or_err) do
		local trimmed_line = vim.fn.trim(line)

		-- Skip blank lines and comments
		if trimmed_line ~= "" and not trimmed_line:match("^#") then
			-- Match ALIAS=TARGET
			local alias, target = trimmed_line:match("^([^=]+)=(.*)$")
			if alias and target then
				local trimmed_alias = vim.fn.trim(alias)
				local trimmed_target = vim.fn.trim(target)

				-- Remove surrounding quotes if present
				if trimmed_target:match('^".*"$') then
					trimmed_target = trimmed_target:sub(2, -2)
				elseif trimmed_target:match("^'.*'$") then
					trimmed_target = trimmed_target:sub(2, -2)
				end

				if trimmed_alias ~= "" and trimmed_target ~= "" then
					refs_data[trimmed_alias] = trimmed_target
				end
			end
		end
	end

	return refs_data
end

--- Load or reload refs file if needed
--- @return boolean success True if refs file was loaded successfully or doesn't exist
function RefsProvider:_load_refs()
	local refs_path = find_refs_file()

	if not refs_path then
		-- No refs file found, that's okay
		self._refs_data = {}
		self._refs_loaded = true
		self._refs_file_path = nil
		self._refs_file_mtime = nil
		return true
	end

	-- Check if we need to reload the file
	local stat = vim.loop.fs_stat(refs_path)
	if not stat then
		return false
	end

	local current_mtime = stat.mtime.sec

	if self._refs_loaded and self._refs_file_path == refs_path and self._refs_file_mtime == current_mtime then
		-- File hasn't changed, use cached data
		return true
	end

	-- Load/reload the file
	local refs_data = parse_refs_file(refs_path)
	if not refs_data then
		return false
	end

	self._refs_data = refs_data
	self._refs_loaded = true
	self._refs_file_path = refs_path
	self._refs_file_mtime = current_mtime

	return true
end

--- Load and validate provider-specific configuration
--- @return boolean success True if config loaded successfully
--- @return string|nil error Error message if config loading failed
function RefsProvider:load_config()
	local provider_config = config.get_provider_config(self.name)

	-- Set defaults and validate configuration
	self._config = {
		cache_ttl = provider_config.cache_ttl or 300, -- 5 minutes default
		reload_on_change = provider_config.reload_on_change ~= false, -- Default true
		case_sensitive = provider_config.case_sensitive ~= false, -- Default true
	}

	return true, nil
end

--- Initialize the provider
--- @return boolean success True if initialization successful
--- @return string|nil error Error message if initialization failed
function RefsProvider:initialize()
	if self._initialized then
		return true, nil
	end

	-- Load configuration first
	local config_success, config_error = self:load_config()
	if not config_success then
		return false, config_error
	end

	-- Load refs file
	local refs_success = self:_load_refs()
	if not refs_success then
		return false, "Failed to load refs file"
	end

	self._initialized = true
	self._authenticated = true -- No authentication needed for refs

	return true, nil
end

--- Resolve reference alias to its target provider reference
--- @param identifier string The variable name (without {{}} braces)
--- @return string|nil value The target provider reference or nil if not found
--- @return string|nil error Error message if resolution failed
function RefsProvider:resolve(identifier)
	-- Ensure we're initialized
	if not self._initialized then
		local success, error = self:initialize()
		if not success then
			return nil, error
		end
	end

	-- Extract variable name from identifier
	local var_name = identifier

	-- Handle explicit refs: prefix
	if identifier:match("^refs:") then
		var_name = identifier:sub(6) -- Remove "refs:" prefix
	end

	-- Validate variable name
	if not var_name or var_name == "" then
		return nil, "Empty variable name"
	end

	-- Check cache first
	local cache_key = "refs:" .. var_name
	local cached_value = self:cache_get(cache_key)
	if cached_value then
		return cached_value, nil
	end

	-- Reload refs file if configured to do so
	if self._config.reload_on_change then
		self:_load_refs()
	end

	local value = nil

	-- 1. Check refs file for exact match first
	if self._refs_data[var_name] then
		value = self._refs_data[var_name]
	end

	-- 2. Try case-insensitive search if enabled and not found
	if not value and not self._config.case_sensitive then
		local lower_var_name = var_name:lower()

		-- Search refs data case-insensitively
		for key, val in pairs(self._refs_data) do
			if key:lower() == lower_var_name then
				value = val
				break
			end
		end
	end

	if value then
		-- Validate that the target contains at least one provider reference
		if not value:match("{{.+:.+}}") then
			return nil,
				"Invalid reference target '"
					.. value
					.. "' - must contain at least one provider reference like {{provider:identifier}}"
		end

		-- Cache the result
		self:cache_set(cache_key, value, self._config.cache_ttl)
		return value, nil
	else
		return nil, "Reference '" .. var_name .. "' not found in refs file"
	end
end

--- Get provider-specific metadata
--- @return table metadata Extended metadata with refs-specific info
function RefsProvider:get_metadata()
	local base_metadata = BaseProvider.get_metadata(self)

	-- Add refs-specific metadata
	base_metadata.refs_loaded = self._refs_loaded
	base_metadata.refs_file_path = self._refs_file_path
	base_metadata.refs_count = self._refs_data and vim.tbl_count(self._refs_data) or 0
	base_metadata.cache_stats = self:cache_stats()

	return base_metadata
end

--- Clean up provider resources
function RefsProvider:cleanup()
	BaseProvider.cleanup(self)

	self._refs_data = {}
	self._refs_loaded = false
	self._refs_file_path = nil
	self._refs_file_mtime = nil
end

return RefsProvider
