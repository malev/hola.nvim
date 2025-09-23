local providers = {}

-- Provider registry
local provider_registry = {
	vault = require("hola.providers.vault"),
	-- Future providers can be added here:
	-- ["aws-secrets"] = require("hola.providers.aws_secrets"),
	-- ["azure-kv"] = require("hola.providers.azure_keyvault"),
}

--- Parse a variable reference to determine if it's a provider or traditional variable
--- @param variable_text string The variable content (without the surrounding {{}} braces)
--- @return table Parsed variable information
function providers.parse_variable_reference(variable_text)
	-- Provider format: provider:path#field
	-- Traditional format: VARIABLE_NAME

	-- Check for whitespace (provider format doesn't allow spaces)
	if variable_text:match("%s") then
		return {
			type = "traditional",
			name = variable_text
		}
	end

	-- Must have exactly one hash for provider format
	local hash_count = 0
	local hash_positions = {}

	for i = 1, #variable_text do
		local char = variable_text:sub(i, i)
		if char == "#" then
			hash_count = hash_count + 1
			table.insert(hash_positions, i)
		end
	end

	-- Must have exactly one hash for provider format
	if hash_count ~= 1 then
		return {
			type = "traditional",
			name = variable_text
		}
	end

	local hash_pos = hash_positions[1]

	-- Find the first colon (there can be multiple colons, but we want the first one)
	local colon_pos = variable_text:find(":")

	-- Must have at least one colon and it must come before the hash
	if not colon_pos or hash_pos <= colon_pos then
		return {
			type = "traditional",
			name = variable_text
		}
	end

	-- Extract components
	local provider = variable_text:sub(1, colon_pos - 1)
	local path = variable_text:sub(colon_pos + 1, hash_pos - 1)
	local field = variable_text:sub(hash_pos + 1)

	-- Validate components are not empty
	if provider == "" or path == "" or field == "" then
		return {
			type = "traditional",
			name = variable_text
		}
	end

	return {
		type = "provider",
		provider = provider,
		path = path,
		field = field
	}
end

--- Extract all variables from text and parse them
--- @param text string The text to search for variables
--- @return table Array of parsed variable information
function providers.extract_variables_from_text(text)
	local variables = {}

	-- Pattern to match {{anything}}
	local pattern = "{{([^}]+)}}"

	for variable_content in text:gmatch(pattern) do
		local parsed = providers.parse_variable_reference(variable_content)

		-- Add original_text for tracking
		parsed.original_text = variable_content

		table.insert(variables, parsed)
	end

	return variables
end

--- Resolve a provider secret
--- @param provider_name string Name of the provider (e.g., "vault")
--- @param path string Secret path (e.g., "secret/api")
--- @param field string Secret field (e.g., "token")
--- @return string|nil, string|nil secret_value, error_message
function providers.resolve_provider_secret(provider_name, path, field)
	local provider = provider_registry[provider_name]
	if not provider then
		return nil, "Unknown provider: " .. provider_name
	end

	return provider.get_secret(path, field)
end

--- Check if a provider is available and enabled
--- @param provider_name string Name of the provider
--- @return boolean True if provider is available
function providers.is_provider_available(provider_name)
	-- Check if provider exists in registry
	if not provider_registry[provider_name] then
		return false
	end

	-- For vault, check if it's enabled in config
	if provider_name == "vault" then
		local config = require("hola.config")
		local vault_config = config.get_vault()
		return vault_config.enabled
	end

	-- Default to true for other providers
	return true
end

return providers