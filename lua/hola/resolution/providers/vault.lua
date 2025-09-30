--- Vault Provider
--- Handles resolution of secrets from HashiCorp Vault using the vault CLI
--- Supports {{vault:path#field}} format for secret resolution

local BaseProvider = require("hola.resolution.base_provider")
local config = require("hola.resolution.config")

local VaultProvider = setmetatable({}, { __index = BaseProvider })
VaultProvider.__index = VaultProvider

--- Create a new vault provider instance
--- @return table provider New provider instance
function VaultProvider.new()
	local self = setmetatable({}, VaultProvider)

	-- Provider metadata
	self.name = "vault"
	self.description = "HashiCorp Vault secrets via vault CLI"
	self.config_files = {}
	self.requires_network = true

	-- Provider-specific state
	self._system_call = {
		execute = function(cmd)
			local result = vim.fn.system(cmd)
			return vim.v.shell_error, result
		end,
	}

	return self
end

--- Check if this provider can handle a given variable
--- @param variable string Full variable like "{{provider:identifier}}"
--- @return boolean True if this provider handles this pattern
function VaultProvider:can_handle(variable)
	-- Handle vault provider format: {{vault:path#field}}
	return variable:match("^{{vault:.+}}$") ~= nil
end

--- Check if vault binary is available
--- @return boolean True if vault is available
function VaultProvider:_is_vault_available()
	local exit_code, _ = self._system_call.execute("which vault 2>/dev/null")
	return exit_code == 0
end

--- Execute vault command with timeout
--- @param cmd string The vault command to execute
--- @return boolean, string success, output/error
function VaultProvider:_execute_vault_command(cmd)
	if not self:_is_vault_available() then
		return false, "Vault CLI not found in PATH"
	end

	-- Add timeout to command
	local timeout_cmd = string.format("timeout %d %s", self._config.timeout_seconds, cmd)

	local exit_code, result = self._system_call.execute(timeout_cmd .. " 2>&1")

	if exit_code == 0 then
		return true, vim.trim(result)
	else
		-- Handle common error cases
		if exit_code == 124 then -- timeout exit code
			return false, "Vault command timed out after " .. self._config.timeout_seconds .. " seconds"
		elseif result:match("permission denied") or result:match("forbidden") then
			return false, "auth_failure"
		elseif result:match("not authenticated") or result:match("invalid token") then
			return false, "auth_failure"
		else
			return false, "Vault command failed: " .. vim.trim(result)
		end
	end
end

--- Parse vault identifier into path and field
--- @param identifier string The identifier like "path#field" or "secrets/api#token"
--- @return string|nil, string|nil path, field
function VaultProvider:_parse_identifier(identifier)
	-- Remove vault: prefix if present
	local clean_identifier = identifier:gsub("^vault:", "")

	-- Split on # to get path and field
	local path, field = clean_identifier:match("^(.+)#(.+)$")

	if not path or not field then
		return nil, nil
	end

	return vim.trim(path), vim.trim(field)
end

--- Load and validate provider-specific configuration
--- @return boolean success True if config loaded successfully
--- @return string|nil error Error message if config loading failed
function VaultProvider:load_config()
	local provider_config = config.get_provider_config(self.name)

	-- Set defaults and validate configuration
	self._config = {
		cache_ttl = provider_config.cache_ttl or 300, -- 5 minutes default
		timeout_seconds = provider_config.timeout_seconds or 10, -- 10 seconds default
		auto_authenticate = provider_config.auto_authenticate ~= false, -- Default true
		debug = provider_config.debug == true, -- Default false
	}

	return true, nil
end

--- Initialize the provider
--- @return boolean success True if initialization successful
--- @return string|nil error Error message if initialization failed
function VaultProvider:initialize()
	if self._initialized then
		return true, nil
	end

	-- Load configuration first
	local config_success, config_error = self:load_config()
	if not config_success then
		return false, config_error
	end

	-- Check if vault CLI is available
	if not self:_is_vault_available() then
		return false, "config_missing"
	end

	-- Check if already authenticated
	if self:is_authenticated() then
		self._initialized = true
		return true, nil
	end

	-- Try to authenticate if auto_authenticate is enabled
	if self._config.auto_authenticate then
		local auth_success, auth_error = self:authenticate()
		if not auth_success then
			return false, auth_error
		end
	end

	self._initialized = true
	return true, nil
end

--- Check if provider can currently resolve values
--- @return boolean True if authenticated and ready
function VaultProvider:is_authenticated()
	if not self:_is_vault_available() then
		self._authenticated = false
		return false
	end

	-- Try vault token lookup to check authentication
	local success, result = self:_execute_vault_command("vault token lookup")
	self._authenticated = success
	return success
end

--- Trigger authentication flow if needed
--- @return boolean success True if authentication successful
--- @return string|nil error Error message if authentication failed
function VaultProvider:authenticate()
	-- For now, we assume the user has already authenticated outside of the plugin
	-- In the future, we could implement interactive authentication flows
	if self:is_authenticated() then
		self._authenticated = true
		return true, nil
	else
		return false, "auth_failure"
	end
end

--- Resolve vault secret to its value
--- @param identifier string The identifier like "path#field"
--- @return string|nil value The resolved value or nil if not found
--- @return string|nil error Error message if resolution failed
function VaultProvider:resolve(identifier)
	-- Ensure we're initialized
	if not self._initialized then
		local success, error = self:initialize()
		if not success then
			return nil, error
		end
	end

	-- Parse the identifier
	local path, field = self:_parse_identifier(identifier)
	if not path or not field then
		return nil, "invalid_identifier"
	end

	-- Skip caching - always fetch fresh values from vault

	-- Check authentication
	if not self:is_authenticated() then
		return nil, "auth_failure"
	end

	-- Build vault command
	local cmd = string.format("vault kv get -field=%s %s", field, path)

	-- Execute command
	local success, result = self:_execute_vault_command(cmd)

	if success then
		return result, nil
	else
		-- Map vault-specific errors to standard error types
		if result == "auth_failure" then
			self._authenticated = false
			return nil, "auth_failure"
		elseif result:match("timeout") then
			return nil, "network_timeout"
		elseif result:match("not found") or result:match("No value found") then
			return nil, "secret_not_found"
		else
			return nil, result
		end
	end
end

--- Get provider-specific metadata
--- @return table metadata Extended metadata with vault-specific info
function VaultProvider:get_metadata()
	local base_metadata = BaseProvider.get_metadata(self)

	-- Add vault-specific metadata
	base_metadata.vault_available = self:_is_vault_available()
	base_metadata.vault_authenticated = self:is_authenticated()
	-- No caching used for vault secrets

	return base_metadata
end

--- Clean up provider resources
function VaultProvider:cleanup()
	BaseProvider.cleanup(self)
end

--- Expose _system_call for testing
VaultProvider._system_call_accessor = function(self)
	return self._system_call
end

return VaultProvider
