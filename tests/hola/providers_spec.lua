local utils = require("hola.utils")

describe("hola provider variable parsing", function()
	describe("provider format detection", function()
		describe("valid provider formats", function()
			it("should detect basic vault path", function()
				local input = "vault:secret/api#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api",
					field = "token"
				}, result)
			end)

			it("should detect deep nested paths", function()
				local input = "vault:secret/deep/nested/path#key"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/deep/nested/path",
					field = "key"
				}, result)
			end)

			it("should detect different providers", function()
				local input = "aws-secrets:prod/db#password"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "aws-secrets",
					path = "prod/db",
					field = "password"
				}, result)
			end)

			it("should detect hyphenated providers", function()
				local input = "azure-kv:app/config#api_key"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "azure-kv",
					path = "app/config",
					field = "api_key"
				}, result)
			end)

			it("should handle underscores in field names", function()
				local input = "vault:secret/path#field_name"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/path",
					field = "field_name"
				}, result)
			end)

			it("should handle hyphens in field names", function()
				local input = "vault:secret/path#field-name"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/path",
					field = "field-name"
				}, result)
			end)

			it("should handle hyphens in paths", function()
				local input = "vault:secret/api-v2/tokens#bearer_token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api-v2/tokens",
					field = "bearer_token"
				}, result)
			end)

			it("should handle underscores in paths", function()
				local input = "vault:secret/api_v2/tokens#bearer_token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api_v2/tokens",
					field = "bearer_token"
				}, result)
			end)

			it("should handle dots in paths and fields", function()
				local input = "vault:secret/api.v2/tokens#bearer.token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api.v2/tokens",
					field = "bearer.token"
				}, result)
			end)

			it("should handle mixed separators", function()
				local input = "vault:kv/my-app_prod.config#api_key-primary"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "kv/my-app_prod.config",
					field = "api_key-primary"
				}, result)
			end)
		end)

		describe("invalid provider formats (should fallback to traditional)", function()
			it("should fallback when missing field", function()
				local input = "vault:secret/api"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:secret/api"
				}, result)
			end)

			it("should fallback when missing path", function()
				local input = "vault#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault#token"
				}, result)
			end)

			it("should fallback when missing provider", function()
				local input = ":secret/api#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = ":secret/api#token"
				}, result)
			end)

			it("should fallback when path is empty", function()
				local input = "vault:"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:"
				}, result)
			end)

			it("should fallback when field is empty", function()
				local input = "vault:secret/api#"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:secret/api#"
				}, result)
			end)

			it("should fallback for traditional variables", function()
				local input = "VAULT_TOKEN"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "VAULT_TOKEN"
				}, result)
			end)

			it("should fallback when multiple hashes present", function()
				local input = "vault:secret/api#token#primary"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:secret/api#token#primary"
				}, result)
			end)
		end)

		describe("edge cases", function()
			it("should handle colon in path", function()
				local input = "vault:secret/api:v2#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api:v2",
					field = "token"
				}, result)
			end)

			it("should handle colon in field name", function()
				local input = "vault:secret/api#token:bearer"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api",
					field = "token:bearer"
				}, result)
			end)
		end)

		describe("case sensitivity", function()
			it("should preserve provider case", function()
				local input = "Vault:secret/api#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "Vault",
					path = "secret/api",
					field = "token"
				}, result)
			end)

			it("should preserve path case", function()
				local input = "vault:Secret/API#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "Secret/API",
					field = "token"
				}, result)
			end)

			it("should preserve field case", function()
				local input = "vault:secret/api#TOKEN"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "secret/api",
					field = "TOKEN"
				}, result)
			end)
		end)

		describe("whitespace handling", function()
			it("should reject variables with internal spaces", function()
				local input = "vault: secret/api#token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault: secret/api#token"
				}, result)
			end)

			it("should reject variables with spaces before hash", function()
				local input = "vault:secret/api #token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:secret/api #token"
				}, result)
			end)

			it("should reject variables with spaces after hash", function()
				local input = "vault:secret/api# token"
				local result = utils.parse_variable_reference(input)
				assert.are.same({
					type = "traditional",
					name = "vault:secret/api# token"
				}, result)
			end)
		end)
	end)

	describe("mixed variable types in same request", function()
		describe("extract_variables_from_text", function()
			it("should find both provider and traditional variables", function()
				local request_text = [[
POST https://api.company.com/data
Authorization: Bearer {{vault:secret/api#token}}
X-User-ID: {{USER_ID}}
X-Environment: {{ENVIRONMENT}}
X-DB-Pass: {{vault:secret/db#password}}
Content-Type: application/json

{
  "api_key": "{{vault:secret/external#api_key}}",
  "user": "{{USERNAME}}",
  "timestamp": "{{CURRENT_TIME}}"
}]]

				local variables = utils.extract_variables_from_text(request_text)

				-- Should find all 7 variables
				assert.equal(7, #variables)

				-- Check that we get the right mix of types
				local provider_vars = {}
				local traditional_vars = {}

				for _, var in ipairs(variables) do
					if var.type == "provider" then
						table.insert(provider_vars, var)
					else
						table.insert(traditional_vars, var)
					end
				end

				assert.equal(3, #provider_vars) -- vault:secret/api#token, vault:secret/db#password, vault:secret/external#api_key
				assert.equal(4, #traditional_vars) -- USER_ID, ENVIRONMENT, USERNAME, CURRENT_TIME
			end)

			it("should correctly parse mixed variables with their details", function()
				local request_text = [[
GET https://{{BASE_URL}}/users
Authorization: Bearer {{vault:auth/tokens#bearer}}
X-API-Key: {{vault:auth/api-keys#primary}}
X-User: {{USERNAME}}
]]

				local variables = utils.extract_variables_from_text(request_text)

				-- Find specific variables
				local vault_bearer, vault_api_key, base_url, username

				for _, var in ipairs(variables) do
					if var.original_text == "vault:auth/tokens#bearer" then
						vault_bearer = var
					elseif var.original_text == "vault:auth/api-keys#primary" then
						vault_api_key = var
					elseif var.original_text == "BASE_URL" then
						base_url = var
					elseif var.original_text == "USERNAME" then
						username = var
					end
				end

				-- Check provider variables
				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "auth/tokens",
					field = "bearer",
					original_text = "vault:auth/tokens#bearer"
				}, vault_bearer)

				assert.are.same({
					type = "provider",
					provider = "vault",
					path = "auth/api-keys",
					field = "primary",
					original_text = "vault:auth/api-keys#primary"
				}, vault_api_key)

				-- Check traditional variables
				assert.are.same({
					type = "traditional",
					name = "BASE_URL",
					original_text = "BASE_URL"
				}, base_url)

				assert.are.same({
					type = "traditional",
					name = "USERNAME",
					original_text = "USERNAME"
				}, username)
			end)
		end)

		describe("variable extraction edge cases", function()
			it("should handle variables in JSON strings", function()
				local json_body = [[{
  "database": {
    "host": "{{DB_HOST}}",
    "password": "{{vault:database/prod#password}}",
    "api_key": "{{vault:external/service#api_key}}"
  },
  "user": "{{USERNAME}}"
}]]

				local variables = utils.extract_variables_from_text(json_body)
				assert.equal(4, #variables)

				-- Should find all 4 variables
				local var_texts = {}
				for _, var in ipairs(variables) do
					table.insert(var_texts, var.original_text)
				end

				local expected_vars = {
					"DB_HOST",
					"vault:database/prod#password",
					"vault:external/service#api_key",
					"USERNAME"
				}

				for _, expected in ipairs(expected_vars) do
					assert.True(vim.tbl_contains(var_texts, expected),
						"Should find variable: " .. expected)
				end
			end)

			it("should handle duplicate variables", function()
				local request_text = [[
POST /api
Authorization: Bearer {{vault:secret/api#token}}
X-Backup-Token: {{vault:secret/api#token}}
X-User: {{USER_ID}}
X-Alt-User: {{USER_ID}}
]]

				local variables = utils.extract_variables_from_text(request_text)

				-- Should find all 4 instances (including duplicates)
				assert.equal(4, #variables)

				-- Count occurrences
				local token_count = 0
				local user_count = 0

				for _, var in ipairs(variables) do
					if var.original_text == "vault:secret/api#token" then
						token_count = token_count + 1
					elseif var.original_text == "USER_ID" then
						user_count = user_count + 1
					end
				end

				assert.equal(2, token_count)
				assert.equal(2, user_count)
			end)

			it("should handle empty request", function()
				local empty_text = ""
				local variables = utils.extract_variables_from_text(empty_text)
				assert.equal(0, #variables)
			end)

			it("should handle request with no variables", function()
				local no_vars_text = [[
GET /api/users
Content-Type: application/json
Authorization: Bearer static-token-123
]]
				local variables = utils.extract_variables_from_text(no_vars_text)
				assert.equal(0, #variables)
			end)
		end)
	end)

	describe("real-world request scenarios", function()
		describe("authentication-heavy requests", function()
			it("should handle multiple auth methods in same request", function()
				local request_text = [[
POST https://api.company.com/auth
Authorization: Basic {{vault:auth/basic#username}}:{{vault:auth/basic#password}}
X-API-Key: {{vault:auth/api-keys#primary}}
X-Service-Token: {{SERVICE_TOKEN}}
Content-Type: application/json

{
  "client_id": "{{CLIENT_ID}}",
  "refresh_token": "{{vault:oauth/tokens#refresh_token}}"
}]]

				local variables = utils.extract_variables_from_text(request_text)
				assert.equal(6, #variables)

				-- Verify we have the right mix
				local vault_vars = {}
				local traditional_vars = {}

				for _, var in ipairs(variables) do
					if var.type == "provider" then
						table.insert(vault_vars, var.original_text)
					else
						table.insert(traditional_vars, var.original_text)
					end
				end

				-- 4 vault variables, 2 traditional
				assert.equal(4, #vault_vars)
				assert.equal(2, #traditional_vars)

				assert.True(vim.tbl_contains(vault_vars, "vault:auth/basic#username"))
				assert.True(vim.tbl_contains(vault_vars, "vault:auth/basic#password"))
				assert.True(vim.tbl_contains(vault_vars, "vault:auth/api-keys#primary"))
				assert.True(vim.tbl_contains(vault_vars, "vault:oauth/tokens#refresh_token"))
				assert.True(vim.tbl_contains(traditional_vars, "SERVICE_TOKEN"))
				assert.True(vim.tbl_contains(traditional_vars, "CLIENT_ID"))
			end)
		end)

		describe("database connection scenarios", function()
			it("should handle mixed database credentials", function()
				local request_text = [[
POST https://db.company.com/query
Host: {{DB_HOST}}
Authorization: Bearer {{vault:database/prod#access_token}}
X-DB-Password: {{vault:database/prod#password}}
X-Connection-Pool: {{CONNECTION_POOL_SIZE}}
Content-Type: application/json

{
  "query": "SELECT * FROM users WHERE env='{{ENVIRONMENT}}'",
  "database": "{{vault:database/prod#database_name}}",
  "timeout": {{QUERY_TIMEOUT}}
}]]

				local variables = utils.extract_variables_from_text(request_text)
				assert.equal(7, #variables)

				-- Find specific vault variables to verify detailed parsing
				local db_token, db_password, db_name
				for _, var in ipairs(variables) do
					if var.original_text == "vault:database/prod#access_token" then
						db_token = var
					elseif var.original_text == "vault:database/prod#password" then
						db_password = var
					elseif var.original_text == "vault:database/prod#database_name" then
						db_name = var
					end
				end

				-- Verify vault variable details
				assert.are.same("vault", db_token.provider)
				assert.are.same("database/prod", db_token.path)
				assert.are.same("access_token", db_token.field)

				assert.are.same("vault", db_password.provider)
				assert.are.same("database/prod", db_password.path)
				assert.are.same("password", db_password.field)

				assert.are.same("vault", db_name.provider)
				assert.are.same("database/prod", db_name.path)
				assert.are.same("database_name", db_name.field)
			end)
		end)

		describe("microservices communication", function()
			it("should handle service-to-service auth patterns", function()
				local request_text = [[
### Call User Service
GET https://{{USER_SERVICE_URL}}/users/{{USER_ID}}
Authorization: Bearer {{vault:services/user-service#jwt_token}}
X-Request-ID: {{REQUEST_ID}}
X-Service-Name: {{SERVICE_NAME}}

### Call Payment Service
POST https://{{PAYMENT_SERVICE_URL}}/charges
Authorization: Bearer {{vault:services/payment-service#api_key}}
X-Idempotency-Key: {{IDEMPOTENCY_KEY}}
Content-Type: application/json

{
  "amount": {{CHARGE_AMOUNT}},
  "currency": "{{CURRENCY}}",
  "customer_id": "{{vault:customers/data#customer_id}}",
  "payment_method": "{{vault:payment/methods#default_method}}"
}]]

				local variables = utils.extract_variables_from_text(request_text)
				assert.equal(12, #variables)

				-- Count provider vs traditional
				local provider_count = 0
				local traditional_count = 0

				for _, var in ipairs(variables) do
					if var.type == "provider" then
						provider_count = provider_count + 1
					else
						traditional_count = traditional_count + 1
					end
				end

				assert.equal(4, provider_count) -- 4 vault variables
				assert.equal(8, traditional_count) -- 8 traditional variables
			end)
		end)

		describe("complex JSON payloads", function()
			it("should handle nested JSON with mixed secret types", function()
				local json_payload = [[{
  "config": {
    "database": {
      "host": "{{DB_HOST}}",
      "port": {{DB_PORT}},
      "credentials": {
        "username": "{{vault:database/prod#username}}",
        "password": "{{vault:database/prod#password}}"
      }
    },
    "external_apis": {
      "stripe": {
        "public_key": "{{STRIPE_PUBLIC_KEY}}",
        "secret_key": "{{vault:payments/stripe#secret_key}}"
      },
      "sendgrid": {
        "api_key": "{{vault:email/sendgrid#api_key}}",
        "webhook_secret": "{{vault:email/sendgrid#webhook_secret}}"
      }
    },
    "features": {
      "debug_mode": {{DEBUG_MODE}},
      "log_level": "{{LOG_LEVEL}}"
    }
  }
}]]

				local variables = utils.extract_variables_from_text(json_payload)
				assert.equal(10, #variables)

				-- Verify specific vault paths
				local vault_paths = {}
				for _, var in ipairs(variables) do
					if var.type == "provider" then
						table.insert(vault_paths, var.path)
					end
				end

				local expected_paths = {
					"database/prod",
					"database/prod", -- appears twice for username and password
					"payments/stripe",
					"email/sendgrid",
					"email/sendgrid" -- appears twice for api_key and webhook_secret
				}

				assert.equal(5, #vault_paths)
				-- Check that expected paths are present
				assert.True(vim.tbl_contains(vault_paths, "database/prod"))
				assert.True(vim.tbl_contains(vault_paths, "payments/stripe"))
				assert.True(vim.tbl_contains(vault_paths, "email/sendgrid"))
			end)
		end)

		describe("performance test scenarios", function()
			it("should handle requests with many variables efficiently", function()
				-- Build a request with 20+ variables
				local headers = {}
				for i = 1, 10 do
					table.insert(headers, string.format("X-Vault-Key-%d: {{vault:perf/test#key_%d}}", i, i))
					table.insert(headers, string.format("X-Env-Var-%d: {{ENV_VAR_%d}}", i, i))
				end

				local request_text = [[
POST https://api.performance-test.com/bulk
]] .. table.concat(headers, "\n") .. [[

Content-Type: application/json

{
  "test_data": "performance"
}]]

				local variables = utils.extract_variables_from_text(request_text)
				assert.equal(20, #variables) -- 10 vault + 10 traditional

				-- Verify parsing performance by checking types
				local provider_count = 0
				local traditional_count = 0

				for _, var in ipairs(variables) do
					if var.type == "provider" then
						provider_count = provider_count + 1
						-- Verify vault variables are parsed correctly
						assert.are.same("vault", var.provider)
						assert.are.same("perf/test", var.path)
					else
						traditional_count = traditional_count + 1
						-- Verify traditional variables are parsed correctly
						assert.matches("ENV_VAR_%d+", var.name)
					end
				end

				assert.equal(10, provider_count)
				assert.equal(10, traditional_count)
			end)
		end)

		describe("error-prone scenarios", function()
			it("should handle malformed variables gracefully", function()
				local request_text = [[
POST https://api.test.com/mixed
Authorization: Bearer {{vault:secret/api#token}}
X-Valid-Traditional: {{VALID_VAR}}
X-Malformed-1: {{vault:missing-field}}
X-Malformed-2: {{vault:secret/api#}}
X-Malformed-3: {{:missing-provider#field}}
X-Nested-Braces: {{invalid{{nested}}format}}
Content-Type: application/json

{
  "valid_vault": "{{vault:data/config#api_key}}",
  "valid_traditional": "{{ANOTHER_VAR}}",
  "malformed_json": "{{vault:incomplete#}}"
}]]

				local variables = utils.extract_variables_from_text(request_text)
				assert.equal(9, #variables)

				-- Count valid vs malformed (malformed should become traditional)
				local valid_vault_count = 0
				local traditional_count = 0

				for _, var in ipairs(variables) do
					if var.type == "provider" then
						valid_vault_count = valid_vault_count + 1
					else
						traditional_count = traditional_count + 1
					end
				end

				assert.equal(2, valid_vault_count) -- Only 2 properly formatted vault variables
				assert.equal(7, traditional_count) -- 2 valid traditional + 5 malformed treated as traditional
			end)
		end)
	end)
end)