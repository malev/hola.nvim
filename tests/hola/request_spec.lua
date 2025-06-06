describe("request", function()
	local Request = require("hola.request") -- Module with execute()
	local Utils -- Deferred require for utils

	-- Store original functions to restore later
	local original_curl_request
	local original_vim_schedule
	local original_vim_uv_now
	local original_utils_parse_headers
	local original_utils_detect_filetype

	-- Mock state variables
	local mock_curl_callback = nil -- Stores the callback passed to curl.request
	local mock_curl_response = nil -- The response our mock curl will send
	local mock_schedule_fn = nil -- Stores the function passed to vim.schedule
	local mock_time = 1000 -- Simple mock timer

	before_each(function()
		-- Clear mock state before each test
		mock_curl_callback = nil
		mock_curl_response = nil
		mock_schedule_fn = nil
		mock_time = 1000 -- Reset timer

		-- Reset potentially cached modules to ensure fresh state if needed
		package.loaded["hola.utils"] = nil
		Utils = require("hola.utils")

		-- Store originals
		original_curl_request = require("plenary.curl").request
		original_vim_schedule = vim.schedule
		original_vim_uv_now = vim.uv.now
		original_utils_parse_headers = Utils.parse_headers
		original_utils_detect_filetype = Utils.detect_filetype

		-- === Mock Implementations ===

		-- Mock plenary.curl.request
		require("plenary.curl").request = function(curl_options)
			print("[TEST] Mock curl.request called")
			-- Store the callback function provided by M.execute
			mock_curl_callback = curl_options.callback
			-- Simulate job starting successfully by returning a fake job ID
			return 999 -- Fake Job ID
		end

		-- Mock vim.schedule
		vim.schedule = function(fn)
			print("[TEST] Mock vim.schedule called")
			-- Store the function that M.execute wants to schedule
			mock_schedule_fn = fn
		end

		-- Mock vim.uv.now for predictable timing
		vim.uv.now = function()
			mock_time = mock_time + math.random(50, 150) -- Simulate some time passing
			return mock_time
		end

		-- Dummy Utils functions (optional, but simplifies test focus)
		-- You could let the real ones run if they are simple and tested elsewhere
		Utils.parse_headers = function(resp)
			print("[TEST] Mock Utils.parse_headers called")
			resp.parsed_headers = { mock = "header" } -- Add dummy parsed headers
			return resp
		end
		Utils.detect_filetype = function(resp)
			print("[TEST] Mock Utils.detect_filetype called")
			resp.filetype = "mock_ft" -- Add dummy filetype
			return resp
		end
	end)

	after_each(function()
		-- Restore original functions
		require("plenary.curl").request = original_curl_request
		vim.schedule = original_vim_schedule
		vim.uv.now = original_vim_uv_now
		Utils.parse_headers = original_utils_parse_headers
		Utils.detect_filetype = original_utils_detect_filetype

		-- Ensure modules are re-requireable if needed
		package.loaded["hola.utils"] = nil
	end)

	it("should call on_complete with processed response on successful request", function()
		-- 1. Setup: Define input and expected mock response
		local request_options = {
			method = "GET",
			path = "http://success.com",
			headers = {},
			body = "",
		}
		mock_curl_response = { -- Data our mock curl will send back
			status = 200,
			headers = { "Content-Type: application/json" }, -- Raw headers
			body = '{"message":"ok"}',
			exit = 0,
			signal = nil,
			stderr = "",
		}

		local callback_called = false
		local final_result = nil

		-- 2. Define the final on_complete callback for this test
		local on_complete_test_callback = function(result)
			print("[TEST] on_complete_test_callback executed")
			callback_called = true
			final_result = result
		end

		-- 3. Execute the function under test
		Request.execute(request_options, on_complete_test_callback)

		-- 4. Assertions: Initial phase
		assert.is_not_nil(mock_curl_callback, "curl.request should have been called and callback stored")
		assert.is_nil(mock_schedule_fn, "vim.schedule should not be called yet")
		assert.is_false(callback_called, "Final on_complete callback should not be called yet")

		-- 5. Simulate curl finishing: Manually call the stored curl callback
		mock_curl_callback(mock_curl_response)

		-- 6. Assertions: After curl callback
		assert.is_not_nil(mock_schedule_fn, "curl callback should have called vim.schedule")
		assert.is_false(callback_called, "Final on_complete callback should *still* not be called yet")

		-- 7. Simulate the scheduler running: Manually call the stored scheduled function
		mock_schedule_fn()

		-- 8. Assertions: Final state
		assert.is_true(callback_called, "Final on_complete callback should have been executed")
		assert.is_not_nil(final_result, "Final result should be received")
		assert.is_nil(final_result.error, "Final result should not have an error key")
		assert.are.equal(200, final_result.status)
		assert.is_not_nil(final_result.elapsed_ms)
		assert.is_table(final_result.parsed_headers, "parsed_headers should exist (from mock)")
		assert.are.equal("json", final_result.filetype, "filetype should exist (from mock)")
		assert.are.equal('{"message":"ok"}', final_result.body)
	end)
end)
