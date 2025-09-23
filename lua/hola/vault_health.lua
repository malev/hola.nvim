local vault_health = {}

-- Health check levels
local LEVELS = {
  OK = "OK",
  WARN = "WARN",
  INFO = "INFO"
}

-- Check if vault binary is available in PATH
local function check_vault_binary()
  local cmd = vim.fn.has("win32") == 1 and "where vault" or "which vault"
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    -- Try to get vault version
    local version_result = vim.fn.system("vault version")
    local version = version_result:match("Vault v([%d%.]+)")
    return {
      level = LEVELS.OK,
      message = version and ("Vault CLI found (v" .. version .. ")") or "Vault CLI found",
      available = true
    }
  else
    return {
      level = LEVELS.WARN,
      message = "Vault CLI not found in PATH",
      suggestion = "Install HashiCorp Vault CLI from https://www.vaultproject.io/downloads if you plan to use vault secrets",
      available = false
    }
  end
end

-- Check if vault is authenticated
local function check_vault_auth()
  local result = vim.fn.system("vault token lookup 2>/dev/null")
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    -- Try to extract TTL from token lookup
    local ttl = result:match("ttl%s+([^\n\r]+)")
    local message = ttl and ("Authenticated (expires in " .. vim.trim(ttl) .. ")") or "Authenticated"
    return {
      level = LEVELS.OK,
      message = message,
      authenticated = true
    }
  else
    return {
      level = LEVELS.WARN,
      message = "Vault not authenticated",
      suggestion = "Run 'vault auth -method=<your-method>' to authenticate if you plan to use vault secrets",
      authenticated = false
    }
  end
end

-- Check vault server connectivity
local function check_vault_connectivity()
  local vault_addr = vim.fn.getenv("VAULT_ADDR") or "not set"
  local result = vim.fn.system("vault status 2>/dev/null")
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    return {
      level = LEVELS.OK,
      message = "Server reachable (" .. vault_addr .. ")",
      reachable = true
    }
  else
    return {
      level = LEVELS.WARN,
      message = "Cannot reach vault server",
      suggestion = "Check VAULT_ADDR environment variable (" .. vault_addr .. ") and network connectivity",
      reachable = false
    }
  end
end

-- Check KV v2 engine access
local function check_kv_access()
  -- Try to list KV mounts to test access
  local result = vim.fn.system("vault secrets list -format=json 2>/dev/null")
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    -- Check if response contains KV v2 engines
    local has_kv = result:match('"kv"') or result:match('"kv%-v2"')
    if has_kv then
      return {
        level = LEVELS.OK,
        message = "KV v2 engine accessible",
        accessible = true
      }
    else
      return {
        level = LEVELS.WARN,
        message = "No KV v2 engines found",
        suggestion = "Ensure you have access to KV v2 secret engines",
        accessible = false
      }
    end
  else
    return {
      level = LEVELS.WARN,
      message = "Cannot check KV engine access",
      suggestion = "Verify vault authentication and permissions",
      accessible = false
    }
  end
end

-- Quick validation for essential requirements
function vault_health.validate_vault_requirements()
  local binary_check = check_vault_binary()
  if not binary_check.available then
    return false, binary_check.message, binary_check.suggestion
  end

  local auth_check = check_vault_auth()
  if not auth_check.authenticated then
    return false, auth_check.message, auth_check.suggestion
  end

  return true
end

-- Comprehensive health check
function vault_health.check_vault()
  local checks = {}

  -- Only run further checks if binary is available
  local binary_check = check_vault_binary()
  table.insert(checks, { name = "Binary", result = binary_check })

  if binary_check.available then
    table.insert(checks, { name = "Authentication", result = check_vault_auth() })
    table.insert(checks, { name = "Connectivity", result = check_vault_connectivity() })
    table.insert(checks, { name = "KV Access", result = check_kv_access() })
  else
    -- Skip other checks if binary not found
    table.insert(checks, {
      name = "Authentication",
      result = { level = LEVELS.INFO, message = "Skipped (vault CLI required)" }
    })
    table.insert(checks, {
      name = "Connectivity",
      result = { level = LEVELS.INFO, message = "Skipped (vault CLI required)" }
    })
    table.insert(checks, {
      name = "KV Access",
      result = { level = LEVELS.INFO, message = "Skipped (vault CLI required)" }
    })
  end

  return checks
end

-- Show health check results in a nice format
function vault_health.show_vault_status()
  local checks = vault_health.check_vault()

  print("=== Hola.nvim Vault Health Check ===")
  print("")

  for _, check in ipairs(checks) do
    local result = check.result
    local icon = result.level == LEVELS.OK and "✓" or
                 result.level == LEVELS.WARN and "⚠" or "ℹ"

    print(string.format("%s %s: %s", icon, check.name, result.message))

    if result.suggestion then
      print("  → " .. result.suggestion)
    end
  end

  print("")

  -- Summary
  local has_warnings = false
  for _, check in ipairs(checks) do
    if check.result.level == LEVELS.WARN then
      has_warnings = true
      break
    end
  end

  if has_warnings then
    print("Note: Warnings don't prevent using hola.nvim - vault features will be disabled")
    print("Run the suggested commands above if you want to use vault secrets")
  else
    print("All checks passed! Vault integration is ready to use.")
  end
end

return vault_health