local test_content = [[
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

describe("request", function()
	_TESTING = true
	local request = require("hola.request")

	describe("parse", function()
		it("parses a request", function()
			local parsed = request.parse(test_content)
			assert.equal(parsed.method, "POST")
			assert.equal(parsed.http_version, "HTTP/1.1")
			assert.equal(parsed.path, "/submit?test=1")
			assert.equal(parsed.body, '{\n  "name": "Test",\n  "value": 123\n}')
			assert.equal(parsed.headers["accept"], "*/*")
		end)
	end)

	describe("remove_comments", function()
		it("removes comments", function()
			local input = "# localhost\nPOST http://localhost"
			local expected = "POST http://localhost"
			assert.are.same(expected, request.remove_comments(input))
		end)

		it("removes comments that stat with white characters", function()
			local str0 = "	# This is an indented comment"
			local str1 = "GET http://example.com/api/users"
			local input = str0 .. "\n" .. str1

			local expected = str1

			assert.are.same(expected, request.remove_comments(input))
		end)

		it("ignores when no comment is present", function()
			local input = "GET http://example.com/api/users"
			local expected = "GET http://example.com/api/users"
			assert.are.same(expected, request.remove_comments(input))
		end)
	end)

	describe("add_user_agent", function()
		it("should add a user agent", function()
			local opts = { headers = {} }
			local output = request.add_user_agent(opts)
			assert.truthy(output.headers)
			assert.is_true(output.headers["user-agent"] == "hola.nvim/0.1")
		end)

		it("should not add a user agent if user agent already present", function()
			local opts = { headers = {} }
			opts.headers["user-agent"] = "test"
			local output = request.add_user_agent(opts)
			assert.is_true(output.headers["user-agent"] == "test")
		end)
	end)

	describe("parse_headers", function()
		it("should return a parsed_headers table", function()
			local input = { headers = { "cache-control: private" } }
			local output = request.parse_headers(input)
			assert.truthy(output.parsed_headers)
		end)

		it("should parse a header", function()
			local input = { headers = { "cache-control: private" } }
			local output = request.parse_headers(input)
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

			local result = request.parse_headers(input)
			assert.is_not_nil(result.parsed_headers)
			assert.are.same(expected_headers, result.parsed_headers)
		end)
	end)

	describe("detect_filetype", function()
		it("should return unknown if Content-Type is missing", function()
			local input = { parsed_headers = {} }
			assert.are.same("unknown", request.detect_filetype(input).filetype)
		end)

		it("should identify json", function()
			local input = { parsed_headers = { ["Content-Type"] = "application/json; charset=utf-8" } }
			assert.are.same("json", request.detect_filetype(input).filetype)
		end)

		it("should identify javascript", function()
			local input = { parsed_headers = { ["Content-Type"] = "application/javascript" } }
			assert.are.same("javascript", request.detect_filetype(input).filetype)
		end)
	end)
end)
