--- Resolution Queue System
--- Implements sequential FIFO queue with blocking operations and circular reference detection
--- This is the core engine that processes variable resolution in the correct order

local M = {}

local config = require('hola.resolution.config')
local feedback = require('hola.resolution.feedback')
local audit = require('hola.resolution.audit')

-- Queue data structures
local ResolutionQueue = {
  pending = {},     -- Variables waiting to be resolved
  completed = {},   -- Variables fully resolved with their values
  failed = {},      -- Variables that failed resolution
}

--- Create a new resolution queue instance
--- @return table queue New queue instance
function ResolutionQueue:new()
  local queue = {
    pending = {},
    completed = {},
    failed = {},
    resolution_stack = {}, -- For circular reference detection
    audit_trail = audit.create_trail()
  }
  setmetatable(queue, { __index = self })
  return queue
end

--- Add a variable to the resolution queue
--- @param variable string Full variable string like "{{provider:identifier}}"
--- @param context table|nil Additional context (parent variable, step number, etc.)
function ResolutionQueue:add(variable, context)
  local item = {
    variable = variable,
    context = context or {},
    step = (context and context.step) or 1,
    parent = (context and context.parent) or nil,
    added_time = vim.loop.hrtime()
  }

  table.insert(self.pending, item)
end

--- Check if a variable has already been resolved
--- @param variable string Variable to check
--- @return boolean True if variable is already resolved
function ResolutionQueue:is_already_resolved(variable)
  return self.completed[variable] ~= nil
end

--- Mark a variable as completed with its resolved value
--- @param variable string The variable that was resolved
--- @param value string The resolved value
--- @param provider_name string Name of provider that resolved it
function ResolutionQueue:mark_completed(variable, value, provider_name)
  self.completed[variable] = {
    value = value,
    provider = provider_name,
    timestamp = vim.loop.hrtime()
  }

  -- Log to audit trail
  self.audit_trail:log_resolution_step(variable, provider_name, {
    status = "fully_resolved",
    output_info = audit.create_secure_metadata(value)
  })
end

--- Mark a variable as failed with error information
--- @param variable string The variable that failed
--- @param error_message string Error message
--- @param provider_name string|nil Name of provider that failed (if any)
function ResolutionQueue:mark_failed(variable, error_message, provider_name)
  self.failed[variable] = {
    error = error_message,
    provider = provider_name,
    timestamp = vim.loop.hrtime()
  }

  -- Log to audit trail
  self.audit_trail:log_resolution_step(variable, provider_name or "unknown", {
    status = "failed",
    error = error_message
  })
end

--- Get queue statistics
--- @return table stats Queue processing statistics
function ResolutionQueue:get_statistics()
  return {
    pending_count = #self.pending,
    completed_count = vim.tbl_count(self.completed),
    failed_count = vim.tbl_count(self.failed),
    resolution_depth = #self.resolution_stack
  }
end

--- Clear the queue and reset state
function ResolutionQueue:reset()
  self.pending = {}
  self.completed = {}
  self.failed = {}
  self.resolution_stack = {}
  self.audit_trail = audit.create_trail()
end

--- Check if queue processing is complete
--- @return boolean True if no more variables to process
function ResolutionQueue:is_complete()
  return #self.pending == 0
end

--- Extract all variables from text using pattern matching
--- @param text string Text to search for variables
--- @return table Array of variable strings
function M.extract_variables(text)
  local variables = {}
  local seen = {} -- Prevent duplicates

  -- Pattern to match {{anything}}
  for match in text:gmatch("{{([^}]+)}}") do
    local full_variable = "{{" .. match .. "}}"
    if not seen[full_variable] then
      table.insert(variables, full_variable)
      seen[full_variable] = true
    end
  end

  return variables
end

--- Check if a value contains variables that need further resolution
--- @param value string Value to check
--- @return boolean True if value contains variables
function M.contains_variables(value)
  return value:match("{{[^}]+}}") ~= nil
end

--- Find the appropriate provider for a variable
--- This function gets the registry passed to avoid circular dependencies
--- @param variable string Variable to resolve
--- @param provider_registry table The provider registry to search
--- @return table|nil provider Provider instance or nil if no provider can handle it
--- @return string provider_name Name of the provider
function M.find_provider(variable, provider_registry)
  for name, provider in pairs(provider_registry) do
    if provider and provider:can_handle(variable) then
      return provider, name
    end
  end

  return nil, nil
end

--- Check for circular reference in resolution stack
--- @param queue table Queue instance
--- @param variable string Variable to check
--- @return boolean is_circular True if circular reference detected
--- @return string|nil cycle_description Description of the circular chain
--- @return number|nil cycle_length Length of the circular chain
function M.detect_circular_reference(queue, variable)
  for i, stack_var in ipairs(queue.resolution_stack) do
    if stack_var == variable then
      -- Build circular reference chain for error message
      local cycle = {}
      for j = i, #queue.resolution_stack do
        table.insert(cycle, queue.resolution_stack[j])
      end
      table.insert(cycle, variable) -- Complete the cycle

      local cycle_description = table.concat(cycle, " → ")
      local cycle_length = #cycle

      return true, cycle_description, cycle_length
    end
  end

  return false, nil, nil
end

--- Detect potential infinite loops before they happen
--- Checks if a variable pattern could lead to circular references
--- @param variable string Variable to analyze
--- @param completed table Already completed resolutions
--- @return boolean is_potentially_circular True if variable could create a loop
--- @return string|nil warning_message Warning message about potential circularity
function M.detect_potential_circular_reference(variable, completed)
  -- Check if this variable's resolved value contains itself
  for completed_var, resolution in pairs(completed) do
    if completed_var == variable then
      -- Already resolved, check if resolution contains the variable again
      if resolution.value and resolution.value:find(vim.pesc(variable)) then
        return true, "Variable " .. variable .. " may resolve to itself"
      end
    end
  end

  -- Check for obvious self-references in variable name patterns
  -- Example: {{env:MY_VAR}} where MY_VAR={{env:MY_VAR}}
  local provider, identifier = variable:match("{{([^:]+):(.+)}}")
  if provider and identifier then
    -- This is a more complex analysis that could be added later
    -- For now, just return false
  end

  return false, nil
end

--- Process all variables in the queue sequentially
--- @param queue table Queue instance
--- @param traditional_sources table Array of traditional variable sources
--- @param provider_registry table The provider registry to use
--- @return table completed Completed resolutions
--- @return table failed Failed resolutions
function M.process_queue(queue, traditional_sources, provider_registry)
  local resolution_config = config.get_resolution_config()
  local max_depth = resolution_config.max_depth or 10
  local timeout_ms = resolution_config.timeout_ms or 30000
  local circular_detection = resolution_config.circular_detection ~= false -- Default to true
  local start_time = vim.loop.hrtime()

  feedback.show_resolving()

  while #queue.pending > 0 do
    -- Check for timeout
    local elapsed_ms = (vim.loop.hrtime() - start_time) / 1000000
    if elapsed_ms > timeout_ms then
      feedback.show_error("timeout", "Resolution timeout after " .. timeout_ms .. "ms")
      -- Mark all remaining pending variables as failed
      for _, pending_item in ipairs(queue.pending) do
        queue:mark_failed(pending_item.variable, "resolution_timeout", nil)
      end
      queue.pending = {} -- Clear pending queue
      break
    end
    local current = table.remove(queue.pending, 1)

    -- Check depth limit
    if current.step > max_depth then
      queue:mark_failed(current.variable, "max_depth_exceeded", nil)
      goto continue
    end

    -- Skip if already resolved (avoid duplicate work)
    if queue:is_already_resolved(current.variable) then
      goto continue
    end

    -- Check for circular reference (if enabled)
    if circular_detection then
      local is_circular, cycle_description, cycle_length = M.detect_circular_reference(queue, current.variable)
      if is_circular then
        local error_msg = string.format("Circular reference detected (cycle length: %d): %s",
          cycle_length or 0, cycle_description)
        queue:mark_failed(current.variable, error_msg, nil)

        -- Log circular reference to audit trail
        queue.audit_trail:log_resolution_step(current.variable, "circular_detection", {
          status = "failed",
          error = error_msg,
          cycle_length = cycle_length
        })

        goto continue
      end
    end

    -- Add to resolution stack
    table.insert(queue.resolution_stack, current.variable)

    -- Find appropriate provider
    local provider, provider_name = M.find_provider(current.variable, provider_registry)
    if not provider then
      queue:mark_failed(current.variable, "no_provider_available", nil)
      table.remove(queue.resolution_stack) -- Remove from stack
      goto continue
    end

    -- Show user feedback for potentially slow operations
    if provider.requires_network then
      feedback.show_variable_resolution(current.variable, provider_name)
    end

    -- Extract identifier from variable (remove {{provider: and }})
    local identifier = current.variable:match("{{[^:]*:(.+)}}")
    if not identifier then
      -- Handle traditional variables without provider prefix
      identifier = current.variable:match("{{(.+)}}")
    end

    if not identifier then
      queue:mark_failed(current.variable, "invalid_variable_format", provider_name)
      table.remove(queue.resolution_stack) -- Remove from stack
      goto continue
    end

    -- Attempt resolution with timing
    local resolve_start = vim.loop.hrtime()
    local value, error = provider:resolve(identifier)
    local resolve_duration = (vim.loop.hrtime() - resolve_start) / 1000000

    -- Clear feedback for network operations
    if provider.requires_network then
      feedback.clear_status()
    end

    if value then
      queue:mark_completed(current.variable, value, provider_name)

      -- Log successful resolution to audit trail
      queue.audit_trail:log_resolution_step(current.variable, provider_name, {
        status = "fully_resolved",
        output_info = audit.create_secure_metadata(value),
        duration_ms = resolve_duration
      })

      -- Handle partial resolution: add new variables to queue
      if M.contains_variables(value) then
        local new_vars = M.extract_variables(value)
        for _, new_var in ipairs(new_vars) do
          queue:add(new_var, {
            parent = current.variable,
            step = current.step + 1
          })
        end

        -- Log partial resolution
        queue.audit_trail:log_resolution_step(current.variable, provider_name, {
          status = "partial_resolution",
          output_info = audit.create_secure_metadata(value),
          duration_ms = resolve_duration
        })
      end
    else
      queue:mark_failed(current.variable, error or "resolution_failed", provider_name)

      -- Log failed resolution
      queue.audit_trail:log_resolution_step(current.variable, provider_name, {
        status = "failed",
        error = error or "resolution_failed",
        duration_ms = resolve_duration
      })
    end

    -- Remove from resolution stack when done
    table.remove(queue.resolution_stack)

    ::continue::
  end

  feedback.clear_status()
  return queue.completed, queue.failed
end

--- Compile template by substituting resolved variables
--- @param text string Original text with variables
--- @param completed table Completed resolutions from queue
--- @param traditional_sources table Traditional variable sources
--- @return string Compiled text with variables substituted
function M.compile_template(text, completed, traditional_sources)
  local result = text

  -- First substitute resolved provider variables
  for variable, resolution in pairs(completed) do
    result = result:gsub(vim.pesc(variable), resolution.value)
  end

  -- Then handle any remaining traditional variables using existing logic
  -- This maintains compatibility with existing .env and OS environment variables
  if traditional_sources then
    result = result:gsub("{{([^}]+)}}", function(var_name_raw)
      local var_name = vim.fn.trim(var_name_raw)

      -- Search through traditional sources
      for _, source_table in ipairs(traditional_sources) do
        if source_table and source_table[var_name] ~= nil then
          return tostring(source_table[var_name])
        end
      end

      -- Variable not found, return original placeholder
      return "{{" .. var_name_raw .. "}}"
    end)
  end

  return result
end

--- Main entry point: resolve all variables in text
--- @param text string Text containing variables to resolve
--- @param traditional_sources table Array of traditional variable sources
--- @param provider_registry table The provider registry to use (passed from init.lua)
--- @return string compiled_text Text with variables resolved
--- @return table errors Array of resolution errors
--- @return table audit_trail Audit trail for debugging
function M.resolve_all_variables(text, traditional_sources, provider_registry)
  local queue = ResolutionQueue:new()

  -- Extract all variables and add to queue
  local variables = M.extract_variables(text)
  for _, var in ipairs(variables) do
    queue:add(var)
  end

  -- Process the queue
  local completed, failed = M.process_queue(queue, traditional_sources, provider_registry or {})

  -- Compile the final template
  local compiled_text = M.compile_template(text, completed, traditional_sources)

  -- Convert failed resolutions to error format
  local errors = {}
  for variable, failure in pairs(failed) do
    table.insert(errors, {
      variable = variable,
      error = failure.error,
      provider = failure.provider
    })
  end

  return compiled_text, errors, queue.audit_trail
end

return M