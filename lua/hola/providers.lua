local M = {}

--- Parse a variable reference to determine if it's a provider or traditional variable
--- @param variable_text string The variable content (without the surrounding {{}} braces)
--- @return table Parsed variable information
function M.parse_variable_reference(variable_text)
	local trimmed = vim.fn.trim(variable_text)

	-- Check if it's a provider reference with format: provider:path#field
	local provider, path, field = trimmed:match("^([^:]+):([^#]+)#([^#]+)$")

	if provider and path and field then
		return {
			type = "provider",
			provider = provider,
			path = path,
			field = field,
			original_text = trimmed
		}
	else
		return {
			type = "traditional",
			name = trimmed,
			original_text = trimmed
		}
	end
end

--- Extract all variables from text and parse them
--- @param text string The text to search for variables
--- @return table Array of parsed variable information
function M.extract_variables_from_text(text)
	local variables = {}

	-- Match {{...}} patterns
	for match in text:gmatch("{{%s*([^}]+)%s*}}") do
		local parsed = M.parse_variable_reference(match)
		table.insert(variables, parsed)
	end

	return variables
end

--- Check if a provider is available and enabled
--- @param provider_name string Name of the provider
--- @return boolean True if provider is available
function M.is_provider_available(provider_name)
	if provider_name == "vault" then
		-- Check if vault is enabled in config
		local ok, config = pcall(require, 'hola.config')
		if not ok then
			return false
		end

		local vault_config = config.get_vault()
		return vault_config.enabled
	end

	-- Add other providers here as they're implemented
	-- elseif provider_name == "aws" then
	--     return check_aws_availability()

	return false
end

--- Resolve a vault secret using vault CLI
--- @param path string Secret path (e.g., "secret/api")
--- @param field string Secret field (e.g., "token")
--- @return string|nil, string|nil secret_value, error_message
local function resolve_vault_secret(path, field)
	-- Build vault command
	local cmd = string.format("vault kv get -field=%s %s", field, path)

	-- Execute vault command
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		return nil, "Failed to execute vault command"
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		-- Check for common vault errors
		if result:match("permission denied") or result:match("forbidden") then
			return nil, "Vault permission denied - check your authentication"
		elseif result:match("not found") then
			return nil, string.format("Secret not found: %s (field: %s)", path, field)
		elseif result:match("command not found") then
			return nil, "Vault CLI not found - ensure vault is installed and in PATH"
		else
			return nil, "Vault error: " .. vim.fn.trim(result)
		end
	end

	-- Clean up the result (remove trailing newline)
	local secret_value = vim.fn.trim(result)

	if secret_value == "" then
		return nil, string.format("Empty value returned for %s:%s", path, field)
	end

	return secret_value, nil
end

--- Resolve a provider secret
--- @param provider_name string Name of the provider (e.g., "vault")
--- @param path string Secret path (e.g., "secret/api")
--- @param field string Secret field (e.g., "token")
--- @return string|nil, string|nil secret_value, error_message
function M.resolve_provider_secret(provider_name, path, field)
	if provider_name == "vault" then
		return resolve_vault_secret(path, field)
	end

	-- Add other providers here as they're implemented
	-- elseif provider_name == "aws" then
	--     return resolve_aws_secret(path, field)

	return nil, "Unknown provider: " .. provider_name
end

return M