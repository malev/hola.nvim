--- OAuth Provider
--- Handles OAuth 2.0 server-to-server authentication token resolution
--- Supports multiple OAuth providers (AWS Cognito, Auth0, Apigee, etc.) via oauth.toml configuration

local BaseProvider = require("hola.resolution.base_provider")
local config = require("hola.resolution.config")
local oauth = require("hola.oauth")
local log = require("hola.log")

local OAuthProvider = setmetatable({}, { __index = BaseProvider })
OAuthProvider.__index = OAuthProvider

--- Create a new OAuth provider instance
--- @return table provider New provider instance
function OAuthProvider.new()
	local self = setmetatable({}, OAuthProvider)

	-- Provider metadata
	self.name = "oauth"
	self.description = "OAuth 2.0 server-to-server authentication tokens"
	self.config_files = { "oauth.toml" }
	self.requires_network = true

	-- Provider-specific state
	self._toml_data = {}
	self._toml_loaded = false
	self._toml_file_path = nil
	self._toml_file_mtime = nil

	return self
end

--- Check if this provider can handle a given variable
--- @param variable string Full variable like "{{provider:identifier}}"
--- @return boolean True if this provider handles this pattern
function OAuthProvider:can_handle(variable)
	-- Handle explicit oauth provider format only: {{oauth:service_name}}
	return variable:match("^{{oauth:.+}}$") ~= nil
end

--- Find oauth.toml file in the current working directory
--- @return string|nil filepath Path to oauth.toml file or nil if not found
local function find_oauth_toml_file()
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		return nil
	end

	local oauth_path = cwd .. "/oauth.toml"
	local stat = vim.loop.fs_stat(oauth_path)

	if stat and stat.type == "file" then
		return oauth_path
	end

	return nil
end

--- Parse TOML file content
--- @param filepath string Path to oauth.toml file
--- @return table|nil toml_data Parsed TOML data or nil on error
local function parse_toml_file(filepath)
	-- Simple TOML parser for [oauth.service_name] sections
	local ok, lines_or_err = pcall(vim.fn.readfile, filepath)
	if not ok or type(lines_or_err) ~= "table" then
		return nil
	end

	local toml_data = {}
	local current_section = nil

	for _, line in ipairs(lines_or_err) do
		local trimmed_line = vim.fn.trim(line)

		-- Skip blank lines and comments
		if trimmed_line ~= "" and not trimmed_line:match("^#") then
			-- Match [oauth.service_name] sections
			local section = trimmed_line:match("^%[oauth%.([^%]]+)%]$")
			if section then
				current_section = section
				toml_data[section] = {}
			elseif current_section then
				-- Match key = "value" or key = value
				local key, value = trimmed_line:match("^([^=]+)%s*=%s*(.*)$")
				if key and value then
					local trimmed_key = vim.fn.trim(key)
					local trimmed_value = vim.fn.trim(value)

					-- Remove surrounding quotes if present
					if trimmed_value:match('^".*"$') then
						trimmed_value = trimmed_value:sub(2, -2)
					elseif trimmed_value:match("^'.*'$") then
						trimmed_value = trimmed_value:sub(2, -2)
					end

					if trimmed_key ~= "" then
						toml_data[current_section][trimmed_key] = trimmed_value
					end
				end
			end
		end
	end

	return toml_data
end

--- Load or reload oauth.toml file if needed
--- @return boolean success True if oauth.toml file was loaded successfully or doesn't exist
function OAuthProvider:_load_toml()
	local toml_path = find_oauth_toml_file()

	if not toml_path then
		-- No oauth.toml file found, that's okay for now
		self._toml_data = {}
		self._toml_loaded = true
		self._toml_file_path = nil
		self._toml_file_mtime = nil
		return true
	end

	-- Check if we need to reload the file
	local stat = vim.loop.fs_stat(toml_path)
	if not stat then
		return false
	end

	local current_mtime = stat.mtime.sec

	if self._toml_loaded and self._toml_file_path == toml_path and self._toml_file_mtime == current_mtime then
		-- File hasn't changed, use cached data
		return true
	end

	-- Load/reload the file
	local toml_data = parse_toml_file(toml_path)
	if not toml_data then
		return false
	end

	self._toml_data = toml_data
	self._toml_loaded = true
	self._toml_file_path = toml_path
	self._toml_file_mtime = current_mtime

	return true
end

--- Load and validate provider-specific configuration
--- @return boolean success True if config loaded successfully
--- @return string|nil error Error message if config loading failed
function OAuthProvider:load_config()
	local provider_config = config.get_provider_config(self.name)

	-- Set defaults and validate configuration
	self._config = {
		reload_on_change = provider_config.reload_on_change ~= false, -- Default true
		network_timeout = provider_config.network_timeout or 10000, -- 10 seconds
	}

	return true, nil
end

--- Initialize the provider
--- @return boolean success True if initialization successful
--- @return string|nil error Error message if initialization failed
function OAuthProvider:initialize()
	if self._initialized then
		return true, nil
	end

	-- Load configuration first
	local config_success, config_error = self:load_config()
	if not config_success then
		return false, config_error
	end

	-- Load oauth.toml file
	local toml_success = self:_load_toml()
	if not toml_success then
		return false, "Failed to load oauth.toml file"
	end

	self._initialized = true
	-- OAuth authentication status depends on individual service configs
	self._authenticated = true

	return true, nil
end

--- Convert TOML service config to format expected by oauth.lua
--- @param service_config table TOML configuration for service
--- @return table env_source Environment variable source compatible with oauth.lua
local function toml_to_oauth_env_source(service_config)
	-- The existing oauth.lua expects specific environment variable names
	-- Map TOML fields to the expected environment variable names
	return {
		OAUTH_TOKEN_URL = service_config.token_url,
		OAUTH_CLIENT_ID = service_config.client_id,
		OAUTH_CLIENT_SECRET = service_config.client_secret,
		OAUTH_GRANT_TYPE = service_config.grant_type,
		OAUTH_SCOPE = service_config.scope,
		OAUTH_AUTH_METHOD = service_config.auth_method,
		OAUTH_CONTENT_TYPE = service_config.content_type,
		OAUTH_AUDIENCE = service_config.audience,
		OAUTH_CUSTOM_HEADERS = service_config.custom_headers,
	}
end

--- Resolve OAuth token for service
--- @param identifier string The variable name (without {{}} braces)
--- @return string|nil value The resolved value or nil if not found
--- @return string|nil error Error message if resolution failed
function OAuthProvider:resolve(identifier)
	-- Ensure we're initialized
	if not self._initialized then
		local success, error = self:initialize()
		if not success then
			return nil, error
		end
	end

	-- Extract service name from identifier
	local service_name = identifier

	-- Handle explicit oauth: prefix
	if identifier:match("^oauth:") then
		service_name = identifier:sub(7) -- Remove "oauth:" prefix
	end

	-- Validate service name
	if not service_name or service_name == "" then
		return nil, "Empty service name"
	end

	-- Reload oauth.toml file if configured to do so
	if self._config.reload_on_change then
		self:_load_toml()
	end

	local service_config = self._toml_data[service_name]
	if not service_config then
		log.error("OAuth service '" .. service_name .. "' not found in oauth.toml")
		return nil, "OAuth service '" .. service_name .. "' not found in oauth.toml"
	end

	-- Validate required configuration
	if not service_config.token_url or not service_config.client_id or not service_config.client_secret then
		return nil,
			"OAuth service '"
				.. service_name
				.. "' missing required configuration (token_url, client_id, client_secret)"
	end

	-- Convert TOML config to environment variable format expected by oauth.lua
	local env_source = toml_to_oauth_env_source(service_config)

	log.debug("Requesting OAuth token for service:", service_name)
	local token, oauth_error = oauth.get_token("default", { env_source })

	if not token then
		local error_type = "auth_failure"
		if oauth_error and oauth_error:find("timeout") then
			error_type = "network_timeout"
		elseif oauth_error and oauth_error:find("Missing OAuth configuration") then
			error_type = "config_missing"
		end

		log.error("OAuth token request failed for service '" .. service_name .. "':", error_type, "-", oauth_error)
		return nil, error_type .. ": " .. (oauth_error or "Unknown OAuth error")
	end

	log.info("Resolved {{" .. identifier .. "}} -> OAuth token (redacted)")
	return token, nil
end

--- Get provider-specific metadata
--- @return table metadata Extended metadata with oauth-specific info
function OAuthProvider:get_metadata()
	local base_metadata = BaseProvider.get_metadata(self)

	-- Add oauth-specific metadata
	base_metadata.toml_loaded = self._toml_loaded
	base_metadata.toml_file_path = self._toml_file_path
	base_metadata.oauth_services = self._toml_data and vim.tbl_count(self._toml_data) or 0

	return base_metadata
end

--- Clean up provider resources
function OAuthProvider:cleanup()
	BaseProvider.cleanup(self)

	self._toml_data = {}
	self._toml_loaded = false
	self._toml_file_path = nil
	self._toml_file_mtime = nil
end

return OAuthProvider
