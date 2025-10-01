local curl = require("plenary.curl")
local utils = require("hola.utils")
local log = require("hola.log")

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
		log.error("Invalid callback provided to request.execute")
		return
	end

	log.info("Sending request:", options.method:upper(), options.path)
	log.trace("Request headers:", options.headers)
	if options.body then
		log.debug("Request body length:", #options.body, "bytes")
	end

	local start_time = vim.uv.now()
	local curl_options = {
		url = options.path,
		method = options.method:upper(),
		headers = options.headers,
		body = options.body,
		timeout = options.timeout or 10000,
		callback = function(response)
			local end_time = vim.uv.now()
			response.elapsed_ms = end_time - start_time

			if response.exit ~= 0 or response.signal ~= nil then
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

				log.error(
					"Request failed:",
					options.method:upper(),
					options.path,
					"-",
					err_msg,
					"(",
					response.elapsed_ms,
					"ms)"
				)

				response.error = err_msg
				vim.schedule(function()
					on_complete(response)
				end)
				return
			end

			local processed_response = response
			utils.parse_headers(processed_response)
			utils.detect_filetype(processed_response)

			local body_size = processed_response.body and #processed_response.body or 0
			log.info(
				"Response received:",
				processed_response.status or "N/A",
				"-",
				options.method:upper(),
				options.path,
				"(",
				response.elapsed_ms,
				"ms,",
				body_size,
				"bytes)"
			)
			log.trace("Response headers:", processed_response.parsed_headers)

			vim.schedule(function()
				on_complete(processed_response)
			end)
		end,
	}
	local job_id = curl.request(curl_options)

	if not job_id then
		log.error("Failed to start HTTP request:", options.method:upper(), options.path)
		vim.notify("Failed to start HTTP request", vim.log.levels.ERROR)
		on_complete({ error = "Failed to initiate curl request job." })
	end
end

return M
