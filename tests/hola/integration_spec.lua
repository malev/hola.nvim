local utils = require("hola.utils")

describe("hola provider integration", function()
	-- Helper to mock vault provider
	local function mock_vault_provider(mock_secrets)
		local vault_provider = require("hola.providers.vault")
		local original_get_secret = vault_provider.get_secret

		vault_provider.get_secret = function(path, field)
			local key = path .. "#" .. field
			if mock_secrets[key] then
				return mock_secrets[key], nil
			else
				return nil, "Secret not found: " .. key
			end
		end

		return function()
			vault_provider.get_secret = original_get_secret
		end
	end

	-- Helper to enable vault
	local function enable_vault()
		local config = require("hola.config")
		local current_config = config.get()
		current_config.vault.enabled = true
		return function()
			current_config.vault.enabled = false
		end
	end

	describe("prepare_provider_secrets", function()
		it("should fetch vault secrets successfully", function()
			local restore_vault = enable_vault()
			local restore_provider = mock_vault_provider({
				["secret/api#token"] = "vault-token-123",
				["secret/db#password"] = "vault-password-456"
			})

			local text = [[
GET https://api.test.com
Authorization: Bearer {{vault:secret/api#token}}
X-DB-Pass: {{vault:secret/db#password}}
X-User: {{USER_ID}}
]]

			local secrets, errors = utils.prepare_provider_secrets(text)

			-- Should have fetched vault secrets
			assert.equals("vault-token-123", secrets["vault:secret/api#token"])
			assert.equals("vault-password-456", secrets["vault:secret/db#password"])

			-- Should have no errors
			assert.equals(0, #errors)

			-- Should not include traditional variables
			assert.is_nil(secrets["USER_ID"])

			restore_provider()
			restore_vault()
		end)

		it("should handle vault errors gracefully", function()
			local restore_vault = enable_vault()
			local restore_provider = mock_vault_provider({
				["secret/api#token"] = "valid-token"
				-- secret/db#password is missing
			})

			local text = [[
Authorization: Bearer {{vault:secret/api#token}}
X-DB-Pass: {{vault:secret/db#password}}
]]

			local secrets, errors = utils.prepare_provider_secrets(text)

			-- Should have one successful secret
			assert.equals("valid-token", secrets["vault:secret/api#token"])

			-- Should have one error
			assert.equals(1, #errors)
			assert.equals("vault:secret/db#password", errors[1].variable)
			assert.matches("Secret not found", errors[1].error)

			restore_provider()
			restore_vault()
		end)

		it("should handle disabled vault provider", function()
			-- Don't enable vault (it's disabled by default)
			local text = [[
Authorization: Bearer {{vault:secret/api#token}}
]]

			local secrets, errors = utils.prepare_provider_secrets(text)

			-- Should have no secrets
			assert.equals(0, vim.tbl_count(secrets))

			-- Should have error about provider not available
			assert.equals(1, #errors)
			assert.equals("vault:secret/api#token", errors[1].variable)
			assert.matches("not available or enabled", errors[1].error)
		end)

		it("should ignore traditional variables", function()
			local text = [[
Authorization: Bearer {{API_TOKEN}}
X-User: {{USER_ID}}
]]

			local secrets, errors = utils.prepare_provider_secrets(text)

			-- Should have no secrets (no provider variables)
			assert.equals(0, vim.tbl_count(secrets))

			-- Should have no errors
			assert.equals(0, #errors)
		end)
	end)

	describe("compile_template_with_providers", function()
		it("should compile request with mixed variable types", function()
			local restore_vault = enable_vault()
			local restore_provider = mock_vault_provider({
				["secret/api#token"] = "vault-secret-token",
				["secret/db#password"] = "vault-db-pass"
			})

			local text = [[
POST https://{{BASE_URL}}/api
Authorization: Bearer {{vault:secret/api#token}}
X-DB-Pass: {{vault:secret/db#password}}
X-User: {{USER_ID}}

{
  "environment": "{{ENVIRONMENT}}"
}]]

			local traditional_sources = {
				{ BASE_URL = "api.test.com", USER_ID = "user123" },
				{ ENVIRONMENT = "production" }
			}

			local compiled, errors = utils.compile_template_with_providers(text, traditional_sources)

			-- Should have no errors
			assert.equals(0, #errors)

			-- Should have compiled all variables
			assert.matches("POST https://api%.test%.com/api", compiled)
			assert.matches("Authorization: Bearer vault%-secret%-token", compiled)
			assert.matches("X%-DB%-Pass: vault%-db%-pass", compiled)
			assert.matches("X%-User: user123", compiled)
			assert.matches('"environment": "production"', compiled)

			restore_provider()
			restore_vault()
		end)

		it("should prioritize provider secrets over traditional variables", function()
			local restore_vault = enable_vault()
			local restore_provider = mock_vault_provider({
				["secret/config#api_key"] = "vault-api-key"
			})

			local text = "API Key: {{vault:secret/config#api_key}}"
			local traditional_sources = {
				{ ["vault:secret/config#api_key"] = "traditional-value" }
			}

			local compiled, errors = utils.compile_template_with_providers(text, traditional_sources)

			-- Should use vault value, not traditional
			assert.equals("API Key: vault-api-key", compiled)
			assert.equals(0, #errors)

			restore_provider()
			restore_vault()
		end)

		it("should handle compilation errors from both providers and traditional sources", function()
			local restore_vault = enable_vault()
			local restore_provider = mock_vault_provider({
				-- secret/api#token is missing
			})

			local text = [[
Authorization: Bearer {{vault:secret/api#token}}
X-User: {{MISSING_VAR}}
]]

			local compiled, errors = utils.compile_template_with_providers(text, {})

			-- Should have provider error
			assert.equals(1, #errors)
			assert.equals("vault:secret/api#token", errors[1].variable)

			-- Should still show unresolved variables in output
			assert.matches("{{vault:secret/api#token}}", compiled)
			assert.matches("{{MISSING_VAR}}", compiled)

			restore_provider()
			restore_vault()
		end)
	end)
end)