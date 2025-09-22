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
local TEST_SINGLE_REQUEST = [[
POST /submit?test=1 HTTP/1.1
Content-Type: application/json
User-Agent:   MyClient/1.0  
Accept: */*
X-Empty-Value: 
X-No-Value:

{
  "name": "Test",
  "value": 123
}]]

local REQUEST_WITH_VARS = "GET https://{{host}}/users"

local INVALID_REQUEST = "Lorem Ipsum is simply dummy"

local TEST_HTTP_CONTENT = [[
# test.http - Example file for testing request parsing

### Get all users
# Simple GET request at the start
GET http://localhost:3000/api/users
Accept: application/json

### Create a new user
# POST request with headers and body
POST https://httpbin.org/post
Content-Type: application/json
X-Custom-Header: MyValue

{
  "name": "John Doe",
  "email": "john.doe@example.com"
}
]]

local EXPECTED_REQUEST = [[
# Simple GET request at the start
GET http://localhost:3000/api/users
Accept: application/json
]]

describe("hola.utils", function()
	describe("get_request_under_cursor", function()
		-- Reset buffer content before each test
		before_each(function()
			-- Clear buffer (optional, but good practice)
			vim.cmd("%d _")
			-- Set the content for the test
			set_buffer_content(vim.split(TEST_HTTP_CONTENT, "\n"))
			-- Reset cursor to a known state (optional)
			set_cursor(1, 0)
		end)

		it("should return the first request when cursor is on the method line", function()
			set_cursor(5, 0) -- Cursor on "GET http://localhost:3000/api/users"
			local expected = vim.fn.trim(EXPECTED_REQUEST)
			local actual = utils.get_request_under_cursor()
			assert.are.equal(expected, actual)
		end)
	end)
	describe("remove_comments", function()
		it("removes comments", function()
			local input = "# localhost\nPOST http://localhost"
			local expected = "POST http://localhost"
			assert.are.same(expected, utils.remove_comments(input))
		end)

		it("removes comments that stat with white characters", function()
			local str0 = "	# This is an indented comment"
			local str1 = "GET http://example.com/api/users"
			local input = str0 .. "\n" .. str1

			local expected = str1

			assert.are.same(expected, utils.remove_comments(input))
		end)

		it("ignores when no comment is present", function()
			local input = "GET http://example.com/api/users"
			local expected = "GET http://example.com/api/users"
			assert.are.same(expected, utils.remove_comments(input))
		end)
	end)
	describe("compile_template", function()
		it("Compiles a request", function()
			local result = utils.compile_template(REQUEST_WITH_VARS, { { host = "localhost" } })
			assert.equal(result, "GET https://localhost/users")
		end)
	end)
	describe("parse_request", function()
		it("parses a request", function()
			local parsed = utils.parse_request(TEST_SINGLE_REQUEST)
			assert.equal(parsed.method, "POST")
			assert.equal(parsed.http_version, "HTTP/1.1")
			assert.equal(parsed.path, "/submit?test=1")
			assert.equal(parsed.body, '{\n  "name": "Test",\n  "value": 123\n}')
			assert.equal(parsed.headers["accept"], "*/*")
		end)
	end)
	describe("validate_request_text", function()
		it("detects valid requests", function()
			assert.truthy(utils.validate_request_text(TEST_SINGLE_REQUEST))
		end)
		it("detects invalid requests", function()
			assert.is_not.True(utils.validate_request_text(INVALID_REQUEST))
		end)
	end)
	describe("add_user_agent", function()
		it("should add a user agent", function()
			local opts = { headers = {} }
			local output = utils.add_user_agent(opts)
			assert.truthy(output.headers)
			assert.is_true(output.headers["user-agent"] == "hola.nvim/0.1")
		end)

		it("should not add a user agent if user agent already present", function()
			local opts = { headers = {} }
			opts.headers["user-agent"] = "test"
			local output = utils.add_user_agent(opts)
			assert.is_true(output.headers["user-agent"] == "test")
		end)
	end)
	describe("parse_headers", function()
		it("should return a parsed_headers table", function()
			local input = { headers = { "cache-control: private" } }
			local output = utils.parse_headers(input)
			assert.truthy(output.parsed_headers)
		end)

		it("should parse a header", function()
			local input = { headers = { "cache-control: private" } }
			local output = utils.parse_headers(input)
			assert.are.same({ ["cache-control"] = "private" }, output.parsed_headers)
		end)

		it("should parse multiple headers", function()
			local input = {
				headers = {
					"Content-Type: application/json",
					"X-Request-ID: abc-123",
					"Cache-Control: no-cache",
				},
			}
			local expected_headers = {
				["content-type"] = "application/json",
				["x-request-id"] = "abc-123",
				["cache-control"] = "no-cache",
			}

			local result = utils.parse_headers(input)
			assert.is_not_nil(result.parsed_headers)
			assert.are.same(expected_headers, result.parsed_headers)
		end)
	end)
	describe("detect_filetype", function()
		it("should return unknown if Content-Type is missing", function()
			local input = { parsed_headers = {} }
			assert.are.same("unknown", utils.detect_filetype(input).filetype)
		end)

		it("should identify json", function()
			local input = { parsed_headers = { ["Content-Type"] = "application/json; charset=utf-8" } }
			assert.are.same("json", utils.detect_filetype(input).filetype)
		end)

		it("should identify javascript", function()
			local input = { parsed_headers = { ["Content-Type"] = "application/javascript" } }
			assert.are.same("javascript", utils.detect_filetype(input).filetype)
		end)
	end)
	describe("basic auth processing", function()
		describe("encode_basic_auth", function()
			it("should base64 encode username:password", function()
				local result = utils.encode_basic_auth("user:password")
				assert.equal("dXNlcjpwYXNzd29yZA==", result)
			end)

			it("should handle empty username", function()
				local result = utils.encode_basic_auth(":password")
				assert.equal("OnBhc3N3b3Jk", result)
			end)

			it("should handle empty password", function()
				local result = utils.encode_basic_auth("user:")
				assert.equal("dXNlcjo=", result)
			end)

			it("should handle special characters in credentials", function()
				local result = utils.encode_basic_auth("user@domain.com:p@ssw0rd!")
				assert.equal("dXNlckBkb21haW4uY29tOnBAc3N3MHJkIQ==", result)
			end)
		end)

		describe("parse_request with basic auth", function()
			it("should detect and encode basic auth header", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Basic user:password
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Basic dXNlcjpwYXNzd29yZA==", parsed.headers["authorization"])
			end)

			it("should leave already encoded basic auth unchanged", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Basic dXNlcjpwYXNzd29yZA==
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Basic dXNlcjpwYXNzd29yZA==", parsed.headers["authorization"])
			end)

			it("should work with template variables in basic auth", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Basic {{USERNAME}}:{{PASSWORD}}
Content-Type: application/json
]]
				local compiled_text = utils.compile_template(request_text, {
					{ USERNAME = "testuser", PASSWORD = "testpass" }
				})
				local parsed = utils.parse_request(compiled_text)
				assert.equal("Basic dGVzdHVzZXI6dGVzdHBhc3M=", parsed.headers["authorization"])
			end)

			it("should handle case insensitive Authorization header", function()
				local request_text = [[
GET /api/users HTTP/1.1
authorization: Basic user:password
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Basic dXNlcjpwYXNzd29yZA==", parsed.headers["authorization"])
			end)

			it("should not process non-basic auth headers", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Bearer token123
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Bearer token123", parsed.headers["authorization"])
			end)

			it("should handle malformed basic auth gracefully", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Basic userpassword
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Basic userpassword", parsed.headers["authorization"])
			end)

			it("should handle multiple colons in basic auth", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Basic user:pass:word
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Basic dXNlcjpwYXNzOndvcmQ=", parsed.headers["authorization"])
			end)
		end)

		describe("parse_request with bearer token", function()
			it("should handle bearer token header", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9", parsed.headers["authorization"])
			end)

			it("should handle bearer token with template variables", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Bearer {{API_TOKEN}}
Content-Type: application/json
]]
				local compiled_text = utils.compile_template(request_text, {
					{ API_TOKEN = "abc123token" }
				})
				local parsed = utils.parse_request(compiled_text)
				assert.equal("Bearer abc123token", parsed.headers["authorization"])
			end)

			it("should handle case insensitive bearer header", function()
				local request_text = [[
GET /api/users HTTP/1.1
authorization: bearer mytoken123
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Bearer mytoken123", parsed.headers["authorization"])
			end)

			it("should trim whitespace from bearer token", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Bearer   token-with-spaces
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Bearer token-with-spaces", parsed.headers["authorization"])
			end)

			it("should handle bearer token with special characters", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Bearer abc123-def456_ghi789.jkl012
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Bearer abc123-def456_ghi789.jkl012", parsed.headers["authorization"])
			end)

			it("should not process non-auth headers", function()
				local request_text = [[
GET /api/users HTTP/1.1
Authorization: Custom mycustomtoken
Content-Type: application/json
]]
				local parsed = utils.parse_request(request_text)
				assert.equal("Custom mycustomtoken", parsed.headers["authorization"])
			end)
		end)
	end)
end)
