local vault_provider = {}

-- Memory cache for vault secrets (session-scoped)
local vault_cache = {}

-- Cache configuration
local CACHE_TTL_SECONDS = 300 -- 5 minutes
local VAULT_TIMEOUT_SECONDS = 10

-- System call wrapper (allows for easier testing)
local system_call = {
	execute = function(cmd)
		local result = vim.fn.system(cmd)
		return vim.v.shell_error, result
	end,
}

--- Check if vault binary is available
--- @return boolean True if vault is available
local function is_vault_available()
	local exit_code, _ = system_call.execute("which vault 2>/dev/null")
	return exit_code == 0
end

--- Execute vault command with timeout
--- @param cmd string The vault command to execute
--- @return boolean, string success, output/error
local function execute_vault_command(cmd)
	if not is_vault_available() then
		return false, "Vault CLI not found in PATH"
	end

	-- Add timeout to command
	local timeout_cmd = string.format("timeout %d %s", VAULT_TIMEOUT_SECONDS, cmd)

	local exit_code, result = system_call.execute(timeout_cmd .. " 2>&1")

	if exit_code == 0 then
		return true, vim.trim(result)
	else
		-- Handle common error cases
		if exit_code == 124 then -- timeout exit code
			return false, "Vault command timed out after " .. VAULT_TIMEOUT_SECONDS .. " seconds"
		elseif result:match("permission denied") or result:match("forbidden") then
			return false, "Vault access denied - check permissions"
		elseif result:match("not authenticated") or result:match("invalid token") then
			return false, "Vault not authenticated - run 'vault auth'"
		else
			return false, "Vault command failed: " .. vim.trim(result)
		end
	end
end

--- Get cache key for a secret
--- @param path string Secret path
--- @param field string Secret field
--- @return string Cache key
local function get_cache_key(path, field)
	return path .. "#" .. field
end

--- Check if cached secret is still valid
--- @param cached_item table Cached secret data
--- @return boolean True if cache is valid
local function is_cache_valid(cached_item)
	if not cached_item then
		return false
	end

	local age = os.time() - cached_item.timestamp
	return age < CACHE_TTL_SECONDS
end

--- Store secret in cache
--- @param cache_key string Cache key
--- @param value string Secret value
local function cache_secret(cache_key, value)
	vault_cache[cache_key] = {
		value = value,
		timestamp = os.time(),
	}
end

--- Get secret from cache
--- @param cache_key string Cache key
--- @return string|nil Cached secret value or nil
local function get_cached_secret(cache_key)
	local cached = vault_cache[cache_key]
	if is_cache_valid(cached) then
		return cached.value
	else
		-- Clean up expired cache entry
		vault_cache[cache_key] = nil
		return nil
	end
end

--- Fetch secret from vault
--- @param path string Secret path (e.g., "secret/api")
--- @param field string Secret field (e.g., "token")
--- @return string|nil, string|nil secret_value, error_message
function vault_provider.get_secret(path, field)
	local cache_key = get_cache_key(path, field)

	-- Check cache first
	local cached_value = get_cached_secret(cache_key)
	if cached_value then
		return cached_value, nil
	end

	-- Build vault command
	local cmd = string.format("vault kv get -field=%s %s", field, path)

	-- Execute command
	local success, result = execute_vault_command(cmd)

	if success then
		-- Cache the result
		cache_secret(cache_key, result)
		return result, nil
	else
		return nil, result
	end
end

--- Clear all cached secrets (useful for testing/debugging)
function vault_provider.clear_cache()
	vault_cache = {}
end

--- Get cache statistics (useful for debugging)
--- @return table Cache statistics
function vault_provider.get_cache_stats()
	local stats = {
		total_entries = 0,
		valid_entries = 0,
		expired_entries = 0,
	}

	for _, cached_item in pairs(vault_cache) do
		stats.total_entries = stats.total_entries + 1
		if is_cache_valid(cached_item) then
			stats.valid_entries = stats.valid_entries + 1
		else
			stats.expired_entries = stats.expired_entries + 1
		end
	end

	return stats
end

--- Expose system_call for testing
vault_provider._system_call = system_call

return vault_provider

