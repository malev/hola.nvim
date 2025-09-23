local vault_provider = require("hola.providers.vault")

describe("hola vault provider", function()
	-- Clear cache before each test
	before_each(function()
		vault_provider.clear_cache()
	end)

	describe("get_secret", function()
		it("should return error when vault CLI not available", function()
			-- Mock system_call to simulate vault not found
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 1, "" -- exit_code = 1, empty output
				end
				return original_execute(cmd)
			end

			local value, error = vault_provider.get_secret("secret/test", "token")

			assert.is_nil(value)
			assert.equals("Vault CLI not found in PATH", error)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should return error when vault command fails", function()
			-- Mock system_call to simulate vault command failure
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("vault kv get") then
					return 1, "Error: permission denied" -- vault command failed
				end
				return original_execute(cmd)
			end

			local value, error = vault_provider.get_secret("secret/test", "token")

			assert.is_nil(value)
			assert.matches("Vault access denied", error)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should return error when vault not authenticated", function()
			-- Mock system_call to simulate auth failure
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("vault kv get") then
					return 2, "Error: not authenticated" -- auth failed
				end
				return original_execute(cmd)
			end

			local value, error = vault_provider.get_secret("secret/test", "token")

			assert.is_nil(value)
			assert.matches("Vault not authenticated", error)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should return error when vault command times out", function()
			-- Mock system_call to simulate timeout
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("timeout.*vault kv get") then
					return 124, "" -- timeout exit code
				end
				return original_execute(cmd)
			end

			local value, error = vault_provider.get_secret("secret/test", "token")

			assert.is_nil(value)
			assert.matches("timed out after 10 seconds", error)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should return secret value on successful vault command", function()
			-- Mock system_call to simulate successful vault command
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("vault kv get") then
					return 0, "secret-token-value-123" -- success
				end
				return original_execute(cmd)
			end

			local value, error = vault_provider.get_secret("secret/test", "token")

			assert.equals("secret-token-value-123", value)
			assert.is_nil(error)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should use cached value on second call", function()
			-- Mock system_call to simulate successful vault command
			local call_count = 0
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("vault kv get") then
					call_count = call_count + 1
					return 0, "cached-secret-value" -- success
				end
				return original_execute(cmd)
			end

			-- First call should execute vault command
			local value1, error1 = vault_provider.get_secret("secret/test", "token")
			assert.equals("cached-secret-value", value1)
			assert.is_nil(error1)
			assert.equals(1, call_count)

			-- Second call should use cache
			local value2, error2 = vault_provider.get_secret("secret/test", "token")
			assert.equals("cached-secret-value", value2)
			assert.is_nil(error2)
			assert.equals(1, call_count) -- Should not increment

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)
	end)

	describe("cache management", function()
		it("should clear cache when requested", function()
			-- Add something to cache first
			local original_execute = vault_provider._system_call.execute
			vault_provider._system_call.execute = function(cmd)
				if cmd:match("which vault") then
					return 0, "/usr/local/bin/vault" -- vault found
				elseif cmd:match("vault kv get") then
					return 0, "test-value" -- success
				end
				return original_execute(cmd)
			end

			vault_provider.get_secret("secret/test", "token")

			local stats_before = vault_provider.get_cache_stats()
			assert.equals(1, stats_before.total_entries)

			vault_provider.clear_cache()

			local stats_after = vault_provider.get_cache_stats()
			assert.equals(0, stats_after.total_entries)

			-- Restore original function
			vault_provider._system_call.execute = original_execute
		end)

		it("should provide cache statistics", function()
			local stats = vault_provider.get_cache_stats()
			assert.equals(0, stats.total_entries)
			assert.equals(0, stats.valid_entries)
			assert.equals(0, stats.expired_entries)
		end)
	end)
end)