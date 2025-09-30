--- Base Provider Class
--- All providers must extend this base class and implement the required interface methods.
--- This provides common functionality and ensures consistent behavior across providers.

local BaseProvider = {}
BaseProvider.__index = BaseProvider

--- Create a new provider instance
--- @return table provider New provider instance
function BaseProvider.new()
	local self = setmetatable({}, BaseProvider)

	-- Provider metadata (must be overridden by subclasses)
	self.name = "base"
	self.description = "Base provider class"
	self.config_files = {}
	self.requires_network = false

	-- Internal state
	self._cache = {}
	self._config = {}
	self._initialized = false
	self._authenticated = false

	return self
end

--- REQUIRED: Determine if this provider should process a given variable
--- @param variable string Full variable like "{{provider:identifier}}"
--- @return boolean True if this provider handles this pattern
function BaseProvider:can_handle(variable)
	error("Provider " .. self.name .. " must implement can_handle() method")
end

--- REQUIRED: Convert identifier to actual value
--- @param identifier string The part after "provider:" in {{provider:identifier}}
--- @return string|nil value The resolved value or nil if not found
--- @return string|nil error Error message if resolution failed
function BaseProvider:resolve(identifier)
	error("Provider " .. self.name .. " must implement resolve() method")
end

--- REQUIRED: Load and validate provider-specific configuration
--- @return boolean success True if config loaded successfully
--- @return string|nil error Error message if config loading failed
function BaseProvider:load_config()
	-- Default implementation: no configuration needed
	self._config = {}
	return true, nil
end

--- REQUIRED: Initialize provider (setup auth, validate config, etc.)
--- @return boolean success True if initialization successful
--- @return string|nil error Error message if initialization failed
function BaseProvider:initialize()
	if self._initialized then
		return true, nil
	end

	local success, error = self:load_config()
	if not success then
		return false, error
	end

	self._initialized = true
	return true, nil
end

--- OPTIONAL: Check if provider can currently resolve values
--- @return boolean True if authenticated and ready
function BaseProvider:is_authenticated()
	return self._authenticated
end

--- OPTIONAL: Trigger authentication flow if needed
--- @return boolean success True if authentication successful
--- @return string|nil error Error message if authentication failed
function BaseProvider:authenticate()
	-- Default implementation: no authentication needed
	self._authenticated = true
	return true, nil
end

--- OPTIONAL: Get cached value for a key
--- @param key string Cache key
--- @return string|nil Cached value or nil if not found/expired
function BaseProvider:cache_get(key)
	-- Ensure cache exists
	if not self._cache then
		self._cache = {}
		return nil
	end

	local cache_entry = self._cache[key]
	if not cache_entry then
		return nil
	end

	-- Check TTL if specified
	if cache_entry.ttl and cache_entry.timestamp then
		local now = os.time()
		if now > cache_entry.timestamp + cache_entry.ttl then
			-- Cache expired, remove entry
			self._cache[key] = nil
			return nil
		end
	end

	return cache_entry.value
end

--- OPTIONAL: Set cached value with optional TTL
--- @param key string Cache key
--- @param value string Value to cache
--- @param ttl number|nil Time to live in seconds (nil = no expiration)
function BaseProvider:cache_set(key, value, ttl)
	-- Ensure cache exists
	if not self._cache then
		self._cache = {}
	end

	self._cache[key] = {
		value = value,
		timestamp = os.time(),
		ttl = ttl,
	}
end

--- OPTIONAL: Clear all cached values
function BaseProvider:cache_clear()
	self._cache = {}
end

--- OPTIONAL: Clear expired cache entries
function BaseProvider:cache_cleanup()
	-- Ensure cache exists
	if not self._cache then
		self._cache = {}
		return 0
	end

	local now = os.time()
	local removed_count = 0

	for key, cache_entry in pairs(self._cache) do
		if cache_entry.ttl and cache_entry.timestamp then
			if now > cache_entry.timestamp + cache_entry.ttl then
				self._cache[key] = nil
				removed_count = removed_count + 1
			end
		end
	end

	return removed_count
end

--- OPTIONAL: Get cache statistics
--- @return table cache_stats Statistics about the cache
function BaseProvider:cache_stats()
	local total_entries = 0
	local expired_entries = 0
	local now = os.time()

	-- Ensure cache exists
	if not self._cache then
		self._cache = {}
	end

	for _, cache_entry in pairs(self._cache) do
		total_entries = total_entries + 1

		if cache_entry.ttl and cache_entry.timestamp then
			if now > cache_entry.timestamp + cache_entry.ttl then
				expired_entries = expired_entries + 1
			end
		end
	end

	return {
		total_entries = total_entries,
		expired_entries = expired_entries,
		active_entries = total_entries - expired_entries,
	}
end

--- OPTIONAL: Clean up resources if needed
function BaseProvider:cleanup()
	self:cache_clear()
	self._initialized = false
	self._authenticated = false
end

--- Get provider metadata for debugging and registration
--- @return table metadata Provider metadata
function BaseProvider:get_metadata()
	return {
		name = self.name,
		description = self.description,
		config_files = self.config_files,
		requires_network = self.requires_network,
		initialized = self._initialized,
		authenticated = self._authenticated,
	}
end

--- Validate that all required methods are implemented
--- This is called during provider registration
--- @return boolean valid True if provider implements all required methods
--- @return string|nil error Error message if validation failed
function BaseProvider:validate_interface()
	local required_methods = { "can_handle", "resolve", "load_config" }

	for _, method_name in ipairs(required_methods) do
		if type(self[method_name]) ~= "function" then
			return false, "Provider " .. self.name .. " missing required method: " .. method_name
		end
	end

	-- Check that can_handle and resolve are not the base implementations
	local base_can_handle = BaseProvider.can_handle
	local base_resolve = BaseProvider.resolve

	if self.can_handle == base_can_handle then
		return false, "Provider " .. self.name .. " must override can_handle() method"
	end

	if self.resolve == base_resolve then
		return false, "Provider " .. self.name .. " must override resolve() method"
	end

	-- Validate provider metadata
	if not self.name or type(self.name) ~= "string" or self.name == "" then
		return false, "Provider must have a valid name"
	end

	if self.name == "base" then
		return false, "Provider name cannot be 'base' (reserved)"
	end

	if not self.description or type(self.description) ~= "string" then
		return false, "Provider must have a description"
	end

	if type(self.config_files) ~= "table" then
		return false, "Provider config_files must be a table"
	end

	if type(self.requires_network) ~= "boolean" then
		return false, "Provider requires_network must be a boolean"
	end

	return true, nil
end

return BaseProvider
