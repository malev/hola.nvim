local curl = require("plenary.curl")
local utils = require("hola.utils")

local M = {}

--- Executes an asynchronous HTTP request using curl.
---
--- @param options table: A table containing the request options:
---   - path (string): The URL path for the request.
---   - method (string): The HTTP method (e.g., "GET", "POST").
---   - headers (table): A table of HTTP headers.
---   - body (string): The request body.
---   - timeout (number): The request timeout in milliseconds (default is 10000).
--- @param on_complete function: A function to be called upon request completion.
---   The on_callback receives a single argument, the response table, which contains:
---   - exit (number): The exit status of the curl command.
---   - signal (number): The signal that terminated the curl command.
---   - status (number): The HTTP status code of the response.
---   - stderr (string): The standard error output from curl.
---   - elapsed_ms (number): The time taken for the request in milliseconds.
---   - error (string): An error message if the request failed.
---   - filetype (string): The detected filetype of the response (if applicable).
---
--- @return nil: This function does not return a value. The callback is invoked with the response.
function M.execute(options, on_complete)
	if type(on_complete) ~= "function" then
		vim.notify("Invalid callback", vim.log.levels.ERROR)
		return
	end

	local start_time = vim.uv.now()
	local curl_options = {
		url = options.path,
		method = options.method:upper(), -- Ensure method is uppercase for curl
		headers = options.headers,
		body = options.body,
		timeout = options.timeout or 10000, -- 10 seconds
		callback = function(response)
			local end_time = vim.uv.now()
			response.elapsed_ms = end_time - start_time
			if response.exit ~= 0 or response.signal ~= nil then
				-- response.signal ~= 0 or response.status == nil or response.status == 0 then
				local err_msg = "Request failed (exit="
					.. tostring(response.exit)
					.. ", signal="
					.. tostring(response.signal)
					.. ")"
				if response.stderr and response.stderr ~= "" then
					err_msg = err_msg .. " Stderr: " .. vim.fn.trim(response.stderr)
				end
				if response.exit == 28 then
					err_msg = "Request Timed Out"
				end
				-- Request failure is already handled by error field
				response.error = err_msg -- Add error field
				-- Call the final callback passed to M.execute
				vim.schedule(function()
					on_complete(response)
				end)
				return -- Don't proceed with post-processing
			end
			-- Post-processing successful response (Sync operations)
			local processed_response = response
			utils.parse_headers(processed_response)
			utils.detect_filetype(processed_response)

			-- Call the final callback passed to M.execute
			vim.schedule(function()
				on_complete(processed_response)
			end)
		end,
	}
	local job_id = curl.request(curl_options)

	if not job_id then
		vim.notify("Failed to start HTTP request", vim.log.levels.ERROR)
		-- Immediately call back with an error if job didn't even start
		on_complete({ error = "Failed to initiate curl request job." })
	end
	-- M.execute returns now, the callback runs later
end

return M
