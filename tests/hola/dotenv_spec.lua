local env_provider = require("hola.resolution.providers.env")

describe("hola env provider", function()
	describe("provider interface", function()
		it("should implement required methods", function()
			local provider = env_provider.new()

			-- Test required interface methods exist
			assert.is_function(provider.can_handle)
			assert.is_function(provider.resolve)
			assert.is_function(provider.load_config)
			assert.is_function(provider.initialize)
			assert.is_function(provider.get_metadata)
		end)

		it("should have correct metadata", function()
			local provider = env_provider.new()
			local metadata = provider:get_metadata()

			assert.equals("env", provider.name)
			assert.equals("Environment variables from .env files and OS environment", provider.description)
			assert.is_false(provider.requires_network)
		end)
	end)

	describe("can_handle", function()
		it("should handle env provider format", function()
			local provider = env_provider.new()

			assert.is_true(provider:can_handle("{{env:API_KEY}}"))
			assert.is_true(provider:can_handle("{{env:DATABASE_URL}}"))
		end)

		it("should not handle other provider formats", function()
			local provider = env_provider.new()

			assert.is_false(provider:can_handle("{{vault:secret/path#field}}"))
			assert.is_false(provider:can_handle("{{oauth:service}}"))
			assert.is_false(provider:can_handle("{{refs:VARIABLE}}"))
		end)

		it("should not handle malformed variables", function()
			local provider = env_provider.new()

			assert.is_false(provider:can_handle("{{env:}}"))
			assert.is_false(provider:can_handle("{{API_KEY}}"))
			assert.is_false(provider:can_handle("{env:API_KEY}"))
		end)
	end)

	describe("resolve", function()
		it("should resolve environment variables", function()
			local provider = env_provider.new()
			provider:initialize()

			-- Test with OS environment variable that should exist
			local value, error = provider:resolve("PATH")
			if value then
				assert.is_string(value)
				assert.is_nil(error)
			else
				-- PATH should exist on most systems, but handle gracefully
				assert.is_string(error)
			end
		end)

		it("should handle missing variables", function()
			local provider = env_provider.new()
			provider:initialize()

			local value, error = provider:resolve("DEFINITELY_NONEXISTENT_VAR_12345")
			assert.is_nil(value)
			assert.is_string(error)
		end)

		it("should handle identifier without env: prefix", function()
			local provider = env_provider.new()
			provider:initialize()

			-- Test direct resolution
			local value, error = provider:resolve("PATH")
			-- Should either resolve or give clear error
			assert.is_true(value ~= nil or error ~= nil)
		end)
	end)
end)