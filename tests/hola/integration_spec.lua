local resolution = require("hola.resolution")

describe("hola resolution system integration", function()
	before_each(function()
		-- Initialize resolution system before each test
		resolution.initialize()
	end)

	describe("resolution system", function()
		it("should initialize successfully", function()
			local success = resolution.initialize()
			assert.is_true(success)
		end)

		it("should register providers", function()
			local providers = resolution.list_providers()
			-- Should have at least env, oauth, and refs (vault might fail without auth)
			assert.is_true(#providers >= 3)
		end)

		it("should resolve simple env variables", function()
			-- Create a test .env file content simulation
			local result, errors = resolution.resolve_variables("GET {{env:TEST_URL}}/test", {})

			-- Should resolve or give clear error
			assert.is_not_nil(result)
			assert.is_table(errors)
		end)

		it("should handle missing variables gracefully", function()
			local result, errors = resolution.resolve_variables("GET {{env:NONEXISTENT_VAR}}/test", {})

			-- Should return original text and have error
			assert.matches("{{env:NONEXISTENT_VAR}}", result)
			assert.is_true(#errors > 0)
		end)

		it("should provide provider info", function()
			local info = resolution.get_provider_info()
			assert.is_table(info)
			assert.is_true(#info > 0)

			-- Each provider should have required fields
			for _, provider in ipairs(info) do
				assert.is_string(provider.name)
				assert.is_string(provider.description)
				assert.is_boolean(provider.enabled)
				assert.is_boolean(provider.available)
			end
		end)
	end)

	describe("debug functionality", function()
		it("should have debug request variables function", function()
			local debug_output = resolution.debug_request_variables("GET {{env:TEST_URL}}/test")
			assert.is_string(debug_output)
			assert.matches("Variables found:", debug_output)
		end)
	end)
end)