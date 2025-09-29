--- Resolution System Entry Point
--- This module provides the main interface for the new provider-based variable resolution system.
--- It maintains provider registry and provides compatibility with existing code.

local M = {}

-- Provider registry - stores all available providers
local provider_registry = {}

-- Module dependencies
local config = require('hola.resolution.config')
local queue = require('hola.resolution.queue')
local audit = require('hola.resolution.audit')
local feedback = require('hola.resolution.feedback')

--- Register a new provider in the system
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
  if provider_registry[name] then
    return false, "Provider '" .. name .. "' is already registered"
  end

  -- Validate provider implements required interface
  local valid, error = provider:validate_interface()
  if not valid then
    return false, error
  end

  -- Check if provider is enabled in configuration
  if not config.is_provider_enabled(name) then
    feedback.show_debug("Provider '" .. name .. "' is disabled in configuration")
    return false, "Provider '" .. name .. "' is disabled in configuration"
  end

  -- Initialize provider
  local init_success, init_error = provider:initialize()
  if not init_success then
    return false, "Provider initialization failed: " .. (init_error or "unknown error")
  end

  -- Register the provider
  provider_registry[name] = provider

  feedback.show_debug("Registered provider: " .. name)
  return true, nil
end

--- Get a registered provider by name
--- @param name string Provider name
--- @return table|nil provider Provider instance or nil if not found
function M.get_provider(name)
  return provider_registry[name]
end

--- Get list of all registered provider names
--- @return table provider_names Array of provider names
function M.list_providers()
  local names = {}
  for name, _ in pairs(provider_registry) do
    table.insert(names, name)
  end
  return names
end

--- Check if a provider is available and ready
--- @param name string Provider name
--- @return boolean available True if provider is available and authenticated
function M.is_provider_available(name)
  local provider = provider_registry[name]
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
  return queue.resolve_all_variables(text, traditional_sources or {}, provider_registry)
end

--- Debug variable resolution for current request
--- This powers the :HolaDebug command
--- @param request_text string The HTTP request text to analyze
--- @return string debug_output Formatted debug information
function M.debug_request_variables(request_text)
  local compiled_text, errors, audit_trail = queue.resolve_all_variables(request_text, {}, provider_registry)

  -- Extract request info for better debug output
  local request_info = {
    line = vim.api.nvim_win_get_cursor(0)[1], -- Current cursor line
    method = "REQUEST", -- Will be extracted from request_text
    url = "URL" -- Will be extracted from request_text
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
  feedback.show_debug("Initializing resolution system...")

  -- Load configuration
  local resolution_config = config.load()
  if not resolution_config then
    feedback.show_error("config_missing", "Failed to load resolution configuration")
    return false
  end

  feedback.show_debug("Configuration loaded successfully")

  -- Register built-in providers
  local providers_to_register = {
    { name = "env", module = "hola.resolution.providers.env" },
    { name = "oauth", module = "hola.resolution.providers.oauth" }
    -- Future providers will be added here
  }

  local registered_count = 0
  for _, provider_info in ipairs(providers_to_register) do
    local ok, provider_module = pcall(require, provider_info.module)
    if ok and provider_module and provider_module.new then
      local provider_instance = provider_module.new()
      local success, error = M.register_provider(provider_info.name, provider_instance)

      if success then
        registered_count = registered_count + 1
        feedback.show_debug("Registered provider: " .. provider_info.name)
      else
        feedback.show_warning("Failed to register provider '" .. provider_info.name .. "': " .. (error or "unknown error"))
      end
    else
      feedback.show_debug("Provider module not available: " .. provider_info.module)
    end
  end

  feedback.show_debug("Resolution system initialized with " .. registered_count .. " providers")
  return true
end

--- Unregister a provider from the system
--- @param name string Provider name to unregister
--- @return boolean success True if unregistration successful
function M.unregister_provider(name)
  local provider = provider_registry[name]
  if not provider then
    return false
  end

  -- Clean up the provider
  if provider.cleanup then
    provider:cleanup()
  end

  provider_registry[name] = nil
  feedback.show_debug("Unregistered provider: " .. name)
  return true
end

--- Get detailed information about all registered providers
--- @return table provider_info Array of provider information
function M.get_provider_info()
  local info = {}

  for name, provider in pairs(provider_registry) do
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
      config_files = metadata.config_files
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
      feedback.show_warning("Failed to reinitialize provider '" .. name .. "': " .. (init_error or "unknown error"))
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
  config.invalidate_cache()

  feedback.show_debug("Cleaned up " .. cleanup_count .. " providers")
end

return M