--- Resolution System Entry Point
--- This module provides the main interface for the new provider-based variable resolution system.
--- It maintains provider registry and provides compatibility with existing code.

local M = {}

local provider_definitions = {}
local provider_cache = {}
local failed_providers = {}
local initialized = false

local config = require("hola.resolution.config")
local queue = require("hola.resolution.queue")
local audit = require("hola.resolution.audit")
local feedback = require("hola.resolution.feedback")
local log = require("hola.log")

--- Register a provider definition for lazy loading
--- @param name string Provider name (e.g., "env", "vault")
--- @param module_path string Path to provider module
--- @param pattern string Pattern that this provider handles (e.g., "^{{vault:.+}}$")
--- @return boolean success True if registration successful
--- @return string|nil error Error message if registration failed
function M.register_provider_definition(name, module_path, pattern)
	-- Validate input parameters
	if not name or type(name) ~= "string" or name == "" then
		return false, "Provider name must be a non-empty string"
	end

	if not module_path or type(module_path) ~= "string" or module_path == "" then
		return false, "Module path must be a non-empty string"
	end

	if not pattern or type(pattern) ~= "string" or pattern == "" then
		return false, "Pattern must be a non-empty string"
	end

	-- Check for naming conflicts
	if provider_definitions[name] then
		return false, "Provider '" .. name .. "' is already registered"
	end

	-- Check if provider is enabled in configuration
	if not config.is_provider_enabled(name) then
		log.debug("Provider '" .. name .. "' is disabled in configuration")
		feedback.show_debug("Provider '" .. name .. "' is disabled in configuration")
		return false, "Provider '" .. name .. "' is disabled in configuration"
	end

	provider_definitions[name] = {
		name = name,
		module_path = module_path,
		pattern = pattern,
		loaded = false,
	}

	log.debug("Registered provider definition:", name)
	feedback.show_debug("Registered provider definition: " .. name)
	return true, nil
end

--- Register a new provider in the system (legacy compatibility)
--- @param name string Provider name (e.g., "env", "vault")
--- @param provider table Provider instance implementing the required interface
--- @return boolean success True if registration successful
--- @return string|nil error Error message if registration failed
function M.register_provider(name, provider)
	-- Validate input parameters
	if not name or type(name) ~= "string" or name == "" then
		return false, "Provider name must be a non-empty string"
	end

	if not provider or type(provider) ~= "table" then
		return false, "Provider must be a table/object"
	end

	-- Check for naming conflicts
	if provider_cache[name] then
		return false, "Provider '" .. name .. "' is already registered"
	end

	-- Validate provider implements required interface
	local valid, error = provider:validate_interface()
	if not valid then
		return false, error
	end

	-- Check if provider is enabled in configuration
	if not config.is_provider_enabled(name) then
		log.debug("Provider '" .. name .. "' is disabled in configuration")
		feedback.show_debug("Provider '" .. name .. "' is disabled in configuration")
		return false, "Provider '" .. name .. "' is disabled in configuration"
	end

	local init_success, init_error = provider:initialize()
	if not init_success then
		log.error("Provider initialization failed for '" .. name .. "':", init_error or "unknown error")
		return false, "Provider initialization failed: " .. (init_error or "unknown error")
	end

	provider_cache[name] = provider

	log.info("Provider registered and initialized:", name)
	feedback.show_debug("Registered provider: " .. name)
	return true, nil
end

--- Lazy load a provider by name
--- @param name string Provider name
--- @return table|nil provider Provider instance or nil if failed to load
--- @return string|nil error Error message if loading failed
function M.load_provider(name)
	-- Check if already loaded
	if provider_cache[name] then
		return provider_cache[name], nil
	end

	-- Check if we have a definition for this provider
	local definition = provider_definitions[name]
	if not definition then
		return nil, "Provider '" .. name .. "' not found"
	end

	-- Check if provider previously failed to load
	if failed_providers[name] then
		log.debug("Provider '" .. name .. "' previously failed to load:", failed_providers[name].error)
		return nil, failed_providers[name].error
	end

	log.debug("Lazy loading provider:", name)
	feedback.show_debug("Lazy loading provider: " .. name)

	local ok, provider_module = pcall(require, definition.module_path)
	if not ok or not provider_module or not provider_module.new then
		local error_msg = "Provider module not available or invalid: " .. definition.module_path
		log.error("Failed to load provider module '" .. name .. "':", error_msg)
		failed_providers[name] = {
			name = name,
			module_path = definition.module_path,
			error = error_msg,
			reason = "module_not_found",
		}
		return nil, error_msg
	end

	-- Create provider instance
	local provider_instance = provider_module.new()

	local success, error = M.register_provider(name, provider_instance)
	if not success then
		log.error("Provider registration failed for '" .. name .. "':", error)
		failed_providers[name] = {
			name = name,
			module_path = definition.module_path,
			error = error,
			reason = "registration_failed",
		}
		return nil, error
	end

	definition.loaded = true
	log.info("Provider successfully loaded:", name)
	return provider_cache[name], nil
end

--- Get a registered provider by name (with lazy loading)
--- @param name string Provider name
--- @return table|nil provider Provider instance or nil if not found
function M.get_provider(name)
	local provider, _ = M.load_provider(name)
	return provider
end

--- Get list of all registered provider names (including definitions)
--- @return table provider_names Array of provider names
function M.list_providers()
	local names = {}
	-- Include loaded providers
	for name, _ in pairs(provider_cache) do
		table.insert(names, name)
	end
	-- Include defined but not loaded providers
	for name, _ in pairs(provider_definitions) do
		if not provider_cache[name] then
			table.insert(names, name)
		end
	end
	return names
end

--- Find provider by variable pattern (with lazy loading)
--- @param variable string Variable like "{{vault:path#field}}"
--- @return table|nil provider Provider instance or nil if not found
--- @return string|nil provider_name Name of the provider that can handle this variable
function M.find_provider_for_variable(variable)
	-- First check loaded providers
	for name, provider in pairs(provider_cache) do
		if provider and provider:can_handle(variable) then
			return provider, name
		end
	end

	-- Check unloaded provider definitions by pattern
	for name, definition in pairs(provider_definitions) do
		if not definition.loaded and variable:match(definition.pattern) then
			-- Lazy load this provider
			local provider, error = M.load_provider(name)
			if provider then
				return provider, name
			else
				feedback.show_debug("Failed to lazy load provider '" .. name .. "': " .. (error or "unknown error"))
			end
		end
	end

	return nil, nil
end

--- Check if a provider is available and ready
--- @param name string Provider name
--- @return boolean available True if provider is available and authenticated
function M.is_provider_available(name)
	local provider = provider_cache[name]
	if not provider then
		return false
	end

	-- Check if provider is enabled in configuration
	if not config.is_provider_enabled(name) then
		return false
	end

	-- Check if provider is initialized
	local metadata = provider:get_metadata()
	if not metadata.initialized then
		return false
	end

	-- Check if provider requires authentication and is authenticated
	if provider.requires_network and not provider:is_authenticated() then
		return false
	end

	return true
end

--- Main variable resolution function
--- This replaces utils.compile_template_with_providers() in the existing codebase
--- @param text string The text containing variables to resolve
--- @param traditional_sources table Array of traditional variable sources (.env, os.environ)
--- @return string compiled_text The text with variables resolved
--- @return table errors Array of resolution errors
function M.resolve_variables(text, traditional_sources)
	-- Ensure resolution system is initialized
	if not initialized then
		local init_success = M.initialize()
		if not init_success then
			return text,
				{
					{
						variable = "system",
						error = "resolution_init_failed",
						details = "Failed to initialize resolution system",
					},
				}
		end
	end

	return queue.resolve_all_variables(text, traditional_sources or {}, M)
end

--- Debug variable resolution for current request
--- This powers the :HolaDebug command
--- @param request_text string The HTTP request text to analyze
--- @return string debug_output Formatted debug information
function M.debug_request_variables(request_text)
	local compiled_text, errors, audit_trail = queue.resolve_all_variables(request_text, {}, M)

	-- Extract request info for better debug output
	local request_info = {
		line = vim.api.nvim_win_get_cursor(0)[1], -- Current cursor line
		method = "REQUEST", -- Will be extracted from request_text
		url = "URL", -- Will be extracted from request_text
	}

	-- Simple request parsing for debug info
	local first_line = request_text:match("([^\n]*)")
	if first_line then
		local method, url = first_line:match("^(%S+)%s+(%S+)")
		if method and url then
			request_info.method = method
			request_info.url = url
		end
	end

	return audit_trail:get_debug_summary(request_info)
end

--- Initialize the resolution system
--- This should be called once during plugin setup
function M.initialize()
	if initialized then
		log.debug("Resolution system already initialized")
		feedback.show_debug("Resolution system already initialized")
		return true
	end

	log.info("Initializing resolution system...")
	feedback.show_debug("Initializing resolution system...")

	local resolution_config = config.load()
	if not resolution_config then
		log.error("Failed to load resolution configuration")
		feedback.show_error("config_missing", "Failed to load resolution configuration")
		return false
	end

	log.debug("Configuration loaded successfully")
	feedback.show_debug("Configuration loaded successfully")

	local provider_definitions_to_register = {
		{ name = "env", module = "hola.resolution.providers.env", pattern = "^{{env:.+}}$" },
		{ name = "oauth", module = "hola.resolution.providers.oauth", pattern = "^{{oauth:.+}}$" },
		{ name = "vault", module = "hola.resolution.providers.vault", pattern = "^{{vault:.+}}$" },
		{ name = "refs", module = "hola.resolution.providers.refs", pattern = "^{{refs:.+}}$" },
	}

	local registered_count = 0
	for _, provider_info in ipairs(provider_definitions_to_register) do
		local success, error =
			M.register_provider_definition(provider_info.name, provider_info.module, provider_info.pattern)
		if success then
			registered_count = registered_count + 1
		else
			log.warn(
				"Failed to register provider definition '" .. provider_info.name .. "': " .. (error or "unknown error")
			)
			feedback.show_debug(
				"Failed to register provider definition '" .. provider_info.name .. "': " .. (error or "unknown error")
			)
		end
	end

	log.info("Resolution system initialized with " .. registered_count .. " provider definitions")
	feedback.show_debug("Resolution system initialized with " .. registered_count .. " provider definitions")
	initialized = true
	return true
end

--- Unregister a provider from the system
--- @param name string Provider name to unregister
--- @return boolean success True if unregistration successful
function M.unregister_provider(name)
	local provider = provider_cache[name]
	if not provider then
		return false
	end

	-- Clean up the provider
	if provider.cleanup then
		provider:cleanup()
	end

	provider_cache[name] = nil

	-- Mark definition as not loaded if it exists
	if provider_definitions[name] then
		provider_definitions[name].loaded = false
	end

	feedback.show_debug("Unregistered provider: " .. name)
	return true
end

--- Get detailed information about all providers (registered and failed)
--- @return table provider_info Array of provider information
function M.get_provider_info()
	local info = {}

	-- Add loaded providers
	for name, provider in pairs(provider_cache) do
		local metadata = provider:get_metadata()
		local available = M.is_provider_available(name)

		table.insert(info, {
			name = name,
			description = metadata.description,
			enabled = config.is_provider_enabled(name),
			available = available,
			initialized = metadata.initialized,
			authenticated = metadata.authenticated,
			requires_network = metadata.requires_network,
			config_files = metadata.config_files,
			status = "registered",
		})
	end

	-- Add defined but not loaded providers
	for name, definition in pairs(provider_definitions) do
		if not provider_cache[name] then
			table.insert(info, {
				name = name,
				description = "Available (not loaded)",
				enabled = config.is_provider_enabled(name),
				available = false,
				initialized = false,
				authenticated = false,
				requires_network = false,
				config_files = {},
				status = "defined",
			})
		end
	end

	-- Add failed providers
	for name, failure_info in pairs(failed_providers) do
		table.insert(info, {
			name = name,
			description = "Failed to load: " .. failure_info.error,
			enabled = config.is_provider_enabled(name),
			available = false,
			initialized = false,
			authenticated = false,
			requires_network = false,
			config_files = {},
			status = "failed",
			error = failure_info.error,
			reason = failure_info.reason,
		})
	end

	return info
end

--- Reinitialize all providers
--- Useful when configuration changes
--- @return boolean success True if all providers reinitialized successfully
function M.reinitialize_providers()
	local success_count = 0
	local total_count = 0

	for name, provider in pairs(provider_registry) do
		total_count = total_count + 1

		-- Clean up existing state
		if provider.cleanup then
			provider:cleanup()
		end

		-- Reinitialize
		local init_success, init_error = provider:initialize()
		if init_success then
			success_count = success_count + 1
		else
			feedback.show_warning(
				"Failed to reinitialize provider '" .. name .. "': " .. (init_error or "unknown error")
			)
		end
	end

	feedback.show_debug("Reinitialized " .. success_count .. " of " .. total_count .. " providers")
	return success_count == total_count
end

--- Clean up the resolution system
--- This should be called during plugin shutdown if needed
function M.cleanup()
	feedback.show_debug("Cleaning up resolution system...")

	local cleanup_count = 0
	for name, provider in pairs(provider_registry) do
		if provider.cleanup then
			provider:cleanup()
			cleanup_count = cleanup_count + 1
		end
	end

	provider_registry = {}
	failed_providers = {}
	initialized = false
	config.invalidate_cache()

	feedback.show_debug("Cleaned up " .. cleanup_count .. " providers")
end

return M
