--- Audit Trail System
--- Provides secure logging and tracking of variable resolution chains
--- Never stores actual values, only safe metadata for debugging

local M = {}

-- Audit trail class
local AuditTrail = {}
AuditTrail.__index = AuditTrail

--- Create secure metadata for a resolved value
--- @param value string The resolved value
--- @return table metadata Safe metadata about the value
function M.create_secure_metadata(value)
  if not value or value == "" then
    return {
      type = "empty",
      length = 0,
      contains_variables = false,
      starts_with = "",
      is_sensitive = false
    }
  end

  local starts_with = ""
  if #value > 0 then
    if #value <= 4 then
      starts_with = value
    else
      starts_with = value:sub(1, 4) .. "••••"
    end
  end

  return {
    type = type(value),
    length = #value,
    contains_variables = value:match("{{[^}]+}}") ~= nil,
    starts_with = starts_with
  }
end


--- Create a new audit trail instance
--- @return table trail New audit trail instance
function M.create_trail()
  local trail = {
    entries = {},
    start_time = vim.loop.hrtime(),
    variables = {} -- Track per-variable resolution chains
  }
  setmetatable(trail, { __index = AuditTrail })
  return trail
end

--- Log a resolution step in the audit trail
--- @param variable string The variable being resolved
--- @param provider_name string Name of the provider handling the resolution
--- @param result table Resolution result information
function AuditTrail:log_resolution_step(variable, provider_name, result)
  local timestamp = vim.loop.hrtime()
  local step_number = #self.entries + 1

  local entry = {
    step = step_number,
    variable = variable,
    provider = provider_name,
    timestamp = timestamp,
    status = result.status or "unknown",
    output_info = result.output_info or {},
    error = result.error,
    duration_ms = result.duration_ms or 0
  }

  table.insert(self.entries, entry)

  -- Track per-variable resolution chain
  if not self.variables[variable] then
    self.variables[variable] = {
      resolution_chain = {},
      final_status = "pending",
      total_resolution_time_ms = 0
    }
  end

  table.insert(self.variables[variable].resolution_chain, entry)

  -- Update variable status
  if result.status == "fully_resolved" then
    self.variables[variable].final_status = "success"
  elseif result.status == "failed" then
    self.variables[variable].final_status = "failed"
  elseif result.status == "partial_resolution" then
    self.variables[variable].final_status = "partial"
  end

  -- Update total time
  self.variables[variable].total_resolution_time_ms =
    self.variables[variable].total_resolution_time_ms + (result.duration_ms or 0)
end

--- Get formatted debug output for a specific variable
--- @param variable string Variable to get debug info for
--- @return string Formatted debug output
function AuditTrail:get_variable_debug_output(variable)
  local var_info = self.variables[variable]
  if not var_info then
    return variable .. " - No resolution attempted"
  end

  local lines = {}
  table.insert(lines, variable)

  for i, step in ipairs(var_info.resolution_chain) do
    local prefix = "└──"
    if i < #var_info.resolution_chain then
      prefix = "├──"
    end

    local status_icon = "✓"
    if step.status == "failed" then
      status_icon = "✗"
    elseif step.status == "partial_resolution" then
      status_icon = "→"
    end

    local output_desc = ""
    if step.output_info and step.output_info.starts_with then
      output_desc = string.format(" → \"%s\" (%d chars)",
        step.output_info.starts_with, step.output_info.length)
    elseif step.error then
      output_desc = string.format(" → [%s] %s", step.status:upper(), step.error)
    end

    local timing = ""
    if step.duration_ms and step.duration_ms > 0 then
      timing = string.format(" %s %.0fms", status_icon, step.duration_ms)
    else
      timing = " " .. status_icon
    end

    table.insert(lines, string.format("%s %s provider%s%s",
      prefix, step.provider, output_desc, timing))
  end

  return table.concat(lines, "\n")
end

--- Get complete debug summary for all variables
--- @param request_info table Information about the HTTP request being debugged
--- @return string Formatted debug summary
function AuditTrail:get_debug_summary(request_info)
  local lines = {}

  -- Header with request info
  if request_info and request_info.line and request_info.method and request_info.url then
    table.insert(lines, string.format("Request at line %d: %s %s",
      request_info.line, request_info.method, request_info.url))
  else
    table.insert(lines, "Variable Resolution Debug")
  end

  -- Variable count
  local var_count = 0
  for _ in pairs(self.variables) do
    var_count = var_count + 1
  end

  if var_count == 0 then
    table.insert(lines, "No variables found in request")
    return table.concat(lines, "\n")
  end

  table.insert(lines, string.format("Variables found: %d", var_count))
  table.insert(lines, "")

  -- Individual variable details
  for variable, _ in pairs(self.variables) do
    table.insert(lines, self:get_variable_debug_output(variable))
    table.insert(lines, "")
  end

  -- Overall status
  local success_count = 0
  local failed_count = 0
  local total_time = 0

  for _, var_info in pairs(self.variables) do
    if var_info.final_status == "success" then
      success_count = success_count + 1
    elseif var_info.final_status == "failed" then
      failed_count = failed_count + 1
    end
    total_time = total_time + var_info.total_resolution_time_ms
  end

  local status_icon = "✓"
  local status_text = "Request would succeed"
  if failed_count > 0 then
    status_icon = "✗"
    status_text = string.format("Request would fail (%d variables unresolved)", failed_count)
  end

  table.insert(lines, string.format("Status: %s %s", status_icon, status_text))
  table.insert(lines, string.format("Total resolution time: %.0fms", total_time))

  return table.concat(lines, "\n")
end

--- Get summary statistics for the audit trail
--- @return table Summary statistics
function AuditTrail:get_statistics()
  local total_time = (vim.loop.hrtime() - self.start_time) / 1000000
  local provider_stats = {}
  local error_stats = {}
  local status_counts = {
    fully_resolved = 0,
    partial_resolution = 0,
    failed = 0,
    pending = 0
  }

  for _, entry in ipairs(self.entries) do
    -- Provider statistics
    if not provider_stats[entry.provider] then
      provider_stats[entry.provider] = {
        count = 0,
        total_time = 0,
        success_count = 0,
        error_count = 0,
        avg_time = 0
      }
    end

    local stats = provider_stats[entry.provider]
    stats.count = stats.count + 1
    stats.total_time = stats.total_time + (entry.duration_ms or 0)
    stats.avg_time = stats.total_time / stats.count

    -- Status counts
    if entry.status then
      status_counts[entry.status] = (status_counts[entry.status] or 0) + 1
    end

    if entry.status == "fully_resolved" then
      stats.success_count = stats.success_count + 1
    elseif entry.status == "failed" then
      stats.error_count = stats.error_count + 1
    end

    -- Error statistics
    if entry.error then
      if not error_stats[entry.error] then
        error_stats[entry.error] = 0
      end
      error_stats[entry.error] = error_stats[entry.error] + 1
    end
  end

  -- Calculate success rate
  local total_attempts = status_counts.fully_resolved + status_counts.failed
  local success_rate = total_attempts > 0 and (status_counts.fully_resolved / total_attempts * 100) or 0

  return {
    total_time_ms = total_time,
    total_steps = #self.entries,
    total_variables = vim.tbl_count(self.variables),
    status_counts = status_counts,
    success_rate = success_rate,
    provider_stats = provider_stats,
    error_stats = error_stats
  }
end


--- Clear old audit entries to manage memory usage
--- @param max_entries number Maximum number of entries to keep
function AuditTrail:cleanup(max_entries)
  max_entries = max_entries or 1000

  if #self.entries > max_entries then
    -- Keep only the most recent entries
    local keep_count = math.floor(max_entries * 0.8) -- Keep 80% of max
    local remove_count = #self.entries - keep_count

    for i = 1, remove_count do
      table.remove(self.entries, 1)
    end
  end
end

return M