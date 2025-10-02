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
		local request_options = {
			method = "GET",
			path = "http://success.com",
			headers = {},
			body = "",
		}
		mock_curl_response = {
			status = 200,
			headers = { "Content-Type: application/json" },
			body = '{"message":"ok"}',
			exit = 0,
			signal = nil,
			stderr = "",
		}

		local callback_called = false
		local final_result = nil

		local on_complete_test_callback = function(result)
			print("[TEST] on_complete_test_callback executed")
			callback_called = true
			final_result = result
		end

		Request.execute(request_options, on_complete_test_callback)

		assert.is_not_nil(mock_curl_callback, "curl.request should have been called and callback stored")
		assert.is_nil(mock_schedule_fn, "vim.schedule should not be called yet")
		assert.is_false(callback_called, "Final on_complete callback should not be called yet")

		mock_curl_callback(mock_curl_response)

		assert.is_not_nil(mock_schedule_fn, "curl callback should have called vim.schedule")
		assert.is_false(callback_called, "Final on_complete callback should *still* not be called yet")

		mock_schedule_fn()

		assert.is_true(callback_called, "Final on_complete callback should have been executed")
		assert.is_not_nil(final_result, "Final result should be received")
		assert.is_nil(final_result.error, "Final result should not have an error key")
		assert.are.equal(200, final_result.status)
		assert.is_not_nil(final_result.elapsed_ms)
		assert.is_table(final_result.parsed_headers, "parsed_headers should exist (from mock)")
		assert.are.equal("json", final_result.filetype, "filetype should exist (from mock)")
		assert.are.equal('{"message":"ok"}', final_result.body)
	end)

	describe("error handling", function()
		it("should return early when callback is not a function", function()
			local request_options = {
				method = "GET",
				path = "http://test.com",
				headers = {},
				body = "",
			}

			Request.execute(request_options, "not a function")

			assert.is_nil(mock_curl_callback, "curl.request should not be called with invalid callback")
		end)

		it("should handle failed job start when curl.request returns nil", function()
			require("plenary.curl").request = function()
				return nil
			end

			local callback_called = false
			local final_result = nil

			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function(result)
					callback_called = true
					final_result = result
				end
			)

			assert.is_true(callback_called, "Callback should be called immediately on job start failure")
			assert.is_not_nil(final_result.error)
			assert.matches("Failed to initiate curl request job", final_result.error)
		end)

		it("should handle timeout error (exit code 28)", function()
			mock_curl_response = {
				exit = 28,
				signal = nil,
				stderr = "Operation timed out",
				status = 0,
			}

			local final_result = nil
			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function(result)
					final_result = result
				end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_not_nil(final_result.error)
			assert.equals("Request Timed Out", final_result.error)
		end)

		it("should handle non-zero exit code with error message", function()
			mock_curl_response = {
				exit = 7,
				signal = nil,
				stderr = "Failed to connect to host",
				status = 0,
			}

			local final_result = nil
			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function(result)
					final_result = result
				end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_not_nil(final_result.error)
			assert.matches("Request failed %(exit=7", final_result.error)
			assert.matches("Failed to connect to host", final_result.error)
		end)

		it("should handle non-nil signal as failure", function()
			mock_curl_response = {
				exit = 0,
				signal = 9,
				stderr = "Process killed",
				status = 0,
			}

			local final_result = nil
			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function(result)
					final_result = result
				end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_not_nil(final_result.error)
			assert.matches("Request failed", final_result.error)
			assert.matches("signal=9", final_result.error)
			assert.matches("Process killed", final_result.error)
		end)

		it("should include stderr in error message when present", function()
			mock_curl_response = {
				exit = 6,
				signal = nil,
				stderr = "Could not resolve host: invalid.domain",
				status = 0,
			}

			local final_result = nil
			Request.execute(
				{ method = "GET", path = "http://invalid.domain", headers = {}, body = "" },
				function(result)
					final_result = result
				end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_not_nil(final_result.error)
			assert.matches("Stderr:", final_result.error)
			assert.matches("Could not resolve host", final_result.error)
		end)

		it("should handle empty stderr gracefully", function()
			mock_curl_response = {
				exit = 1,
				signal = nil,
				stderr = "",
				status = 0,
			}

			local final_result = nil
			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function(result)
					final_result = result
				end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_not_nil(final_result.error)
			assert.matches("Request failed %(exit=1", final_result.error)
			assert.is_not.matches("Stderr:", final_result.error)
		end)

		it("should skip post-processing on failed request", function()
			local parse_headers_called = false
			local detect_filetype_called = false

			Utils.parse_headers = function(resp)
				parse_headers_called = true
				return resp
			end
			Utils.detect_filetype = function(resp)
				detect_filetype_called = true
				return resp
			end

			mock_curl_response = {
				exit = 7,
				signal = nil,
				stderr = "Connection failed",
				status = 0,
			}

			Request.execute(
				{ method = "GET", path = "http://test.com", headers = {}, body = "" },
				function() end
			)

			mock_curl_callback(mock_curl_response)
			mock_schedule_fn()

			assert.is_false(parse_headers_called, "parse_headers should not be called on error")
			assert.is_false(detect_filetype_called, "detect_filetype should not be called on error")
		end)
	end)
end)
