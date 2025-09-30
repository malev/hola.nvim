--- User Feedback System
--- Provides status updates and notifications during variable resolution
--- Handles showing/clearing status messages for slow operations

local M = {}

-- Current status state
local current_status = {
  message = nil,
  start_time = nil,
  provider = nil
}

--- Show a status message to the user
--- @param message string Status message to display
--- @param provider_name string|nil Name of provider causing the status (optional)
function M.show_status(message, provider_name)
  current_status = {
    message = message,
    start_time = vim.loop.hrtime(),
    provider = provider_name
  }

  -- Use DEBUG level to avoid disrupting normal workflow
  vim.notify(message, vim.log.levels.DEBUG, {
    title = "Resolution Status",
    timeout = false, -- Don't auto-dismiss
  })
end

--- Clear the current status message
function M.clear_status()
  if current_status.message then
    local elapsed_ms = (vim.loop.hrtime() - current_status.start_time) / 1000000

    -- Show completion message if operation took more than 100ms
    if elapsed_ms > 100 then
      local completion_msg = string.format("Completed in %.0fms", elapsed_ms)
      if current_status.provider then
        completion_msg = current_status.provider .. " - " .. completion_msg
      end

      vim.notify(completion_msg, vim.log.levels.DEBUG, {
        title = "Resolution Status"
      })
    end
  end

  current_status = {
    message = nil,
    start_time = nil,
    provider = nil
  }
end

--- Show status for a specific provider operation
--- @param provider_name string Name of the provider
--- @param operation string Description of the operation
function M.show_provider_status(provider_name, operation)
  local message = string.format("%s: %s...", provider_name, operation)
  M.show_status(message, provider_name)
end

--- Show generic "resolving variables" status
function M.show_resolving()
  M.show_status("Resolving variables...")
end

--- Show status when processing a specific variable
--- @param variable string The variable being processed
--- @param provider_name string Name of the provider handling it
function M.show_variable_resolution(variable, provider_name)
  local message = string.format("Resolving %s via %s...", variable, provider_name)
  M.show_status(message, provider_name)
end

--- Get current status information
--- @return table|nil Status information or nil if no status active
function M.get_current_status()
  if not current_status.message then
    return nil
  end

  local elapsed_ms = (vim.loop.hrtime() - current_status.start_time) / 1000000

  return {
    message = current_status.message,
    provider = current_status.provider,
    elapsed_ms = elapsed_ms
  }
end

--- Check if a status message is currently active
--- @return boolean True if status is active
function M.is_status_active()
  return current_status.message ~= nil
end

--- Show error message with appropriate formatting
--- @param error_type string Type of error (from standardized error types)
--- @param message string Error message
--- @param provider_name string|nil Provider that caused the error
function M.show_error(error_type, message, provider_name)
  local title = "Resolution Error"
  if provider_name then
    title = title .. " (" .. provider_name .. ")"
  end

  local formatted_message = message
  if error_type then
    formatted_message = string.format("[%s] %s", error_type, message)
  end

  vim.notify(formatted_message, vim.log.levels.ERROR, {
    title = title
  })
end

--- Show warning message
--- @param message string Warning message
--- @param provider_name string|nil Provider that caused the warning
function M.show_warning(message, provider_name)
  local title = "Resolution Warning"
  if provider_name then
    title = title .. " (" .. provider_name .. ")"
  end

  vim.notify(message, vim.log.levels.WARN, {
    title = title
  })
end

--- Show success message
--- @param message string Success message
--- @param provider_name string|nil Provider that succeeded
function M.show_success(message, provider_name)
  local title = "Resolution Success"
  if provider_name then
    title = title .. " (" .. provider_name .. ")"
  end

  vim.notify(message, vim.log.levels.INFO, {
    title = title
  })
end

--- Show debug message (only if debug is enabled)
--- @param message string Debug message
--- @param provider_name string|nil Provider context
function M.show_debug(message, provider_name)
  local config = require('hola.resolution.config')
  local debug_config = config.get_debug_config()

  if not debug_config.enabled then
    return
  end

  local title = "Resolution Debug"
  if provider_name then
    title = title .. " (" .. provider_name .. ")"
  end

  vim.notify(message, vim.log.levels.DEBUG, {
    title = title
  })
end

--- Show progress for multiple variable resolution
--- @param completed number Number of variables completed
--- @param total number Total number of variables
--- @param current_variable string|nil Currently processing variable
function M.show_progress(completed, total, current_variable)
  local progress = string.format("Resolving variables... (%d/%d)", completed, total)

  if current_variable then
    progress = progress .. string.format(" - %s", current_variable)
  end

  M.show_status(progress)
end

return M