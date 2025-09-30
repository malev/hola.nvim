--- Provider Configuration Management
--- Handles loading and validation of provider-specific configuration
--- Supports multiple configuration sources with proper precedence

local M = {}

-- Default configuration
local DEFAULT_CONFIG = {
	providers = {
		env = {
			enabled = true,
			search_paths = { ".", "..", "~/.config/hola" },
			cache_ttl = 300, -- 5 minutes
		},
		vault = {
			timeout_seconds = 10,
			cache_ttl = 300, -- 5 minutes
			auto_authenticate = true,
		},
	},
	debug = {
		enabled = false,
		max_audit_entries = 100,
		redact_sensitive = true,
	},
	resolution = {
		max_depth = 10,
		timeout_ms = 30000, -- 30 seconds
		circular_detection = true,
	},
}

-- Cached configuration
local cached_config = nil

--- Expand tilde in file paths
--- @param path string File path potentially containing ~
--- @return string Expanded file path
local function expand_path(path)
	if path:sub(1, 1) == "~" then
		local home = os.getenv("HOME") or os.getenv("USERPROFILE")
		if home then
			return home .. path:sub(2)
		end
	end
	return path
end

--- Load configuration from a single file
--- @param filepath string Path to configuration file
--- @return table|nil config Configuration table or nil if file doesn't exist/is invalid
local function load_config_file(filepath)
	local expanded_path = expand_path(filepath)

	-- Check if file exists
	local stat = vim.loop.fs_stat(expanded_path)
	if not stat or stat.type ~= "file" then
		return nil
	end

	-- Try to load as Lua file
	local ok, config = pcall(dofile, expanded_path)
	if ok and type(config) == "table" then
		return config
	end

	-- TODO: Add support for JSON/TOML config files if needed
	vim.notify(
		"Invalid configuration file format: " .. expanded_path,
		vim.log.levels.WARN,
		{ title = "Resolution Config" }
	)

	return nil
end

--- Merge two configuration tables deeply
--- @param base table Base configuration
--- @param override table Override configuration
--- @return table Merged configuration
local function merge_config(base, override)
	local result = vim.deepcopy(base)

	for key, value in pairs(override) do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = merge_config(result[key], value)
		else
			result[key] = value
		end
	end

	return result
end

--- Load configuration from environment variables
--- @return table Environment-based configuration
local function load_env_config()
	local env_config = {
		providers = {},
		debug = {},
		resolution = {},
	}

	-- Check for provider-specific environment variables
	if os.getenv("HOLA_ENV_ENABLED") then
		env_config.providers.env = env_config.providers.env or {}
		env_config.providers.env.enabled = os.getenv("HOLA_ENV_ENABLED") == "true"
	end

	if os.getenv("HOLA_DEBUG_ENABLED") then
		env_config.debug.enabled = os.getenv("HOLA_DEBUG_ENABLED") == "true"
	end

	if os.getenv("HOLA_MAX_DEPTH") then
		local max_depth = tonumber(os.getenv("HOLA_MAX_DEPTH"))
		if max_depth then
			env_config.resolution.max_depth = max_depth
		end
	end

	return env_config
end

--- Get configuration file search paths
--- @return table Array of file paths to search for configuration
local function get_config_search_paths()
	local paths = {}

	-- 1. Current working directory
	table.insert(paths, vim.fn.getcwd() .. "/.hola/resolution.lua")

	-- 2. Project root (git root)
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
	if git_root ~= "" and git_root ~= vim.fn.getcwd() then
		table.insert(paths, git_root .. "/.hola/resolution.lua")
	end

	-- 3. User config directory
	table.insert(paths, "~/.config/hola/resolution.lua")

	return paths
end

--- Load complete configuration from all sources
--- @return table Complete configuration
function M.load()
	if cached_config then
		return cached_config
	end

	local config = vim.deepcopy(DEFAULT_CONFIG)

	-- Load from configuration files (in precedence order)
	local search_paths = get_config_search_paths()
	for _, path in ipairs(search_paths) do
		local file_config = load_config_file(path)
		if file_config then
			config = merge_config(config, file_config)
			vim.notify("Loaded resolution config from: " .. path, vim.log.levels.DEBUG, { title = "Resolution Config" })
			break -- Use first found config file
		end
	end

	-- Override with environment variables
	local env_config = load_env_config()
	config = merge_config(config, env_config)

	cached_config = config
	return config
end

--- Get configuration for a specific provider
--- @param provider_name string Name of the provider
--- @return table Provider configuration
function M.get_provider_config(provider_name)
	local config = M.load()
	return config.providers[provider_name] or {}
end

--- Get debug configuration
--- @return table Debug configuration
function M.get_debug_config()
	local config = M.load()
	return config.debug
end

--- Get resolution configuration
--- @return table Resolution configuration
function M.get_resolution_config()
	local config = M.load()
	return config.resolution
end

--- Check if a provider is enabled in configuration
--- @param provider_name string Name of the provider
--- @return boolean True if provider is enabled
function M.is_provider_enabled(provider_name)
	local provider_config = M.get_provider_config(provider_name)
	return provider_config.enabled ~= false -- Default to enabled
end

--- Invalidate cached configuration
--- Forces reload on next access
function M.invalidate_cache()
	cached_config = nil
end

--- Validate configuration structure
--- @param config table Configuration to validate
--- @return boolean valid True if configuration is valid
--- @return string|nil error Error message if validation failed
function M.validate(config)
	if type(config) ~= "table" then
		return false, "Configuration must be a table"
	end

	-- Validate providers section
	if config.providers and type(config.providers) ~= "table" then
		return false, "providers section must be a table"
	end

	-- Validate debug section
	if config.debug and type(config.debug) ~= "table" then
		return false, "debug section must be a table"
	end

	if config.debug and config.debug.max_audit_entries then
		if type(config.debug.max_audit_entries) ~= "number" or config.debug.max_audit_entries < 1 then
			return false, "debug.max_audit_entries must be a positive number"
		end
	end

	-- Validate resolution section
	if config.resolution and type(config.resolution) ~= "table" then
		return false, "resolution section must be a table"
	end

	if config.resolution and config.resolution.max_depth then
		if type(config.resolution.max_depth) ~= "number" or config.resolution.max_depth < 1 then
			return false, "resolution.max_depth must be a positive number"
		end
	end

	return true, nil
end

return M
