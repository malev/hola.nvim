local utils = require("hola.utils")

-- Helper function to set buffer content easily
local function set_buffer_content(lines_table)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines_table)
end

-- Helper function to set cursor position (1-based)
local function set_cursor(line, col)
	vim.api.nvim_win_set_cursor(0, { line, col })
end

-- Define the test content once
local TEST_HTTP_CONTENT = {
	"# test.http - Example file for testing request parsing", -- L1
	"", -- L2
	"### Get all users", -- L3
	"# Simple GET request at the start", -- L4
	"GET http://localhost:3000/api/users", -- L5
	"Accept: application/json", -- L6
	"", -- L7
	"", -- L8
	"### Create a new user", -- L9
	"# POST request with headers and body", -- L10
	"POST https://httpbin.org/post", -- L11
	"Content-Type: application/json", -- L12
	"X-Custom-Header: MyValue", -- L13
	"", -- L14
	"{", -- L15
	'    "name": "John Doe",', -- L16
	'    "email": "john.doe@example.com"', -- L17
	"}", -- L18
	"", -- L19
	"  ### Update a user (Note leading space on separator)", -- L20
	"# PUT request, minimal", -- L21
	"PUT http://localhost:3000/api/users/123", -- L22
	"Content-Type: application/json", -- L23
	"", -- L24
	'{"status": "updated"}', -- L25
	"", -- L26
	"", -- L27
	"### Delete a user", -- L28
	"# DELETE request at the end", -- L29
	"DELETE http://localhost:3000/api/users/456", -- L30
	"Authorization: Bearer your_token_here", -- L31
	"", -- L32
	"", -- L33
	"### Another GET for testing edge cases", -- L34
	"GET https://httpbin.org/get?search=test", -- L35
	"", -- L36
}

describe("hola.utils", function()
	describe("get_request_under_cursor", function()
		-- Reset buffer content before each test
		before_each(function()
			-- Clear buffer (optional, but good practice)
			vim.cmd("%d _")
			-- Set the content for the test
			set_buffer_content(TEST_HTTP_CONTENT)
			-- Reset cursor to a known state (optional)
			set_cursor(1, 0)
		end)

		it("should return the first request when cursor is on the method line", function()
			set_cursor(5, 0) -- Cursor on "GET http://localhost:3000/api/users"
			local expected = vim.fn.trim([[
# Simple GET request at the start
GET http://localhost:3000/api/users
Accept: application/json]])
			local actual = utils.get_request_under_cursor()
			assert.are.equal(expected, actual)
		end)
	end)
end)
