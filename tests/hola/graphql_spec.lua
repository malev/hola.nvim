local graphql = require("hola.graphql")

describe("hola.graphql", function()
	describe("parse_graphql_body", function()
		it("should parse a simple query without variables", function()
			local body = [[
query {
  user(id: "1") {
    name
    email
  }
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_not_nil(result)
			assert.is_not_nil(result.query)
			assert.is_true(result.query:match("user") ~= nil)
			assert.is_nil(result.variables)
		end)

		it("should parse a query with variables", function()
			local body = [[
query GetUser($id: ID!) {
  user(id: $id) {
    name
    email
  }
}

{
  "id": "1"
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_not_nil(result)
			assert.is_not_nil(result.query)
			assert.is_true(result.query:match("GetUser") ~= nil)
			assert.is_not_nil(result.variables)
			assert.are.equal("1", result.variables.id)
		end)

		it("should parse a mutation with variables", function()
			local body = [[
mutation CreateUser($input: UserInput!) {
  createUser(input: $input) {
    id
    name
  }
}

{
  "input": {
    "name": "John Doe",
    "email": "john@example.com"
  }
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_not_nil(result)
			assert.is_true(result.query:match("mutation") ~= nil)
			assert.is_not_nil(result.variables)
			assert.is_not_nil(result.variables.input)
			assert.are.equal("John Doe", result.variables.input.name)
		end)

		it("should handle complex nested variables", function()
			local body = [[
query SearchProducts($filters: FilterInput!) {
  products(filters: $filters) {
    items {
      id
      name
    }
  }
}

{
  "filters": {
    "category": "electronics",
    "priceRange": {
      "min": 100,
      "max": 500
    },
    "tags": ["new", "featured"]
  }
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_not_nil(result)
			assert.is_not_nil(result.variables)
			assert.are.equal("electronics", result.variables.filters.category)
			assert.are.equal(100, result.variables.filters.priceRange.min)
			assert.are.equal(2, #result.variables.filters.tags)
		end)

		it("should return error for empty query", function()
			local body = ""
			local result = graphql.parse_graphql_body(body)
			-- Empty query should return error
			assert.is_nil(result)
		end)

		it("should return error for invalid JSON variables", function()
			local body = [[
query GetUser($id: ID!) {
  user(id: $id) {
    name
  }
}

{
  "id": "1",  // Invalid: trailing comma
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_nil(result)
		end)

		it("should handle shorthand query syntax", function()
			local body = [[
{
  user(id: "1") {
    name
  }
}
]]
			local result = graphql.parse_graphql_body(body)
			assert.is_not_nil(result)
			assert.is_not_nil(result.query)
		end)
	end)

	describe("transform_to_http", function()
		it("should transform GRAPHQL request to POST with JSON body", function()
			local parsed_request = {
				method = "GRAPHQL",
				path = "http://localhost:4000/graphql",
				headers = {
					["authorization"] = "Bearer token123",
				},
				body = [[
query {
  user(id: "1") {
    name
  }
}
]],
			}

			local result = graphql.transform_to_http(parsed_request)
			assert.is_not_nil(result)
			assert.are.equal("POST", result.method)
			assert.is_not_nil(result.body)

			-- Parse the body to verify structure
			local ok, body_data = pcall(vim.fn.json_decode, result.body)
			assert.is_true(ok)
			assert.is_not_nil(body_data.query)
			assert.are.equal("application/json", result.headers["content-type"])
		end)

		it("should include variables in transformed request", function()
			local parsed_request = {
				method = "GRAPHQL",
				path = "http://localhost:4000/graphql",
				headers = {},
				body = [[
query GetUser($id: ID!) {
  user(id: $id) {
    name
  }
}

{
  "id": "123"
}
]],
			}

			local result = graphql.transform_to_http(parsed_request)
			assert.is_not_nil(result)

			local ok, body_data = pcall(vim.fn.json_decode, result.body)
			assert.is_true(ok)
			assert.is_not_nil(body_data.query)
			assert.is_not_nil(body_data.variables)
			assert.are.equal("123", body_data.variables.id)
		end)

		it("should not transform non-GRAPHQL requests", function()
			local parsed_request = {
				method = "POST",
				path = "http://localhost:4000/api",
				headers = {},
				body = "test body",
			}

			local result = graphql.transform_to_http(parsed_request)
			assert.are.equal("POST", result.method)
			assert.are.equal("test body", result.body)
		end)
	end)

	describe("format_response", function()
		it("should detect GraphQL response with data", function()
			local response = {
				body = vim.fn.json_encode({
					data = {
						user = {
							name = "John Doe",
							email = "john@example.com",
						},
					},
				}),
				filetype = "json",
			}

			local result = graphql.format_response(response)
			assert.is_true(result.is_graphql)
			assert.is_nil(result.graphql_errors)
		end)

		it("should detect GraphQL response with errors", function()
			local response = {
				body = vim.fn.json_encode({
					errors = {
						{
							message = "Field 'user' not found",
							locations = { { line = 2, column = 3 } },
						},
					},
				}),
				filetype = "json",
			}

			local result = graphql.format_response(response)
			assert.is_true(result.is_graphql)
			assert.is_not_nil(result.graphql_errors)
			assert.are.equal(1, #result.graphql_errors)
			assert.are.equal("Field 'user' not found", result.graphql_errors[1].message)
		end)

		it("should handle response with both data and errors", function()
			local response = {
				body = vim.fn.json_encode({
					data = {
						user = vim.NIL,
					},
					errors = {
						{
							message = "User not found",
							path = { "user" },
						},
					},
				}),
				filetype = "json",
			}

			local result = graphql.format_response(response)
			assert.is_true(result.is_graphql)
			assert.is_not_nil(result.graphql_errors)
			assert.are.equal(1, #result.graphql_errors)
		end)

		it("should not affect non-GraphQL responses", function()
			local response = {
				body = vim.fn.json_encode({
					message = "Success",
					data = { id = 1 },
				}),
				filetype = "json",
			}

			local result = graphql.format_response(response)
			assert.is_nil(result.is_graphql)
		end)
	end)

	describe("is_graphql_query", function()
		it("should recognize query keyword", function()
			assert.is_true(graphql.is_graphql_query("query { user { name } }"))
			assert.is_true(graphql.is_graphql_query("query GetUser { user { name } }"))
			assert.is_true(graphql.is_graphql_query("  query  { user { name } }"))
		end)

		it("should recognize mutation keyword", function()
			assert.is_true(graphql.is_graphql_query("mutation { createUser { id } }"))
			assert.is_true(graphql.is_graphql_query("mutation CreateUser { createUser { id } }"))
		end)

		it("should recognize subscription keyword", function()
			assert.is_true(graphql.is_graphql_query("subscription { userUpdated { id } }"))
		end)

		it("should recognize shorthand query syntax", function()
			assert.is_true(graphql.is_graphql_query("{ user { name } }"))
			assert.is_true(graphql.is_graphql_query("{ user(id: 1) { name } }"))
		end)

		it("should reject non-GraphQL text", function()
			assert.is_false(graphql.is_graphql_query("POST /api/users"))
			assert.is_false(graphql.is_graphql_query("{ 'not': 'graphql' }"))
			assert.is_false(graphql.is_graphql_query(""))
		end)
	end)

	describe("validate_query", function()
		it("should validate correct queries", function()
			local valid, err = graphql.validate_query("query { user { name } }")
			assert.is_true(valid)
			assert.is_nil(err)
		end)

		it("should detect mismatched braces", function()
			local valid, err = graphql.validate_query("query { user { name }")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("should detect mismatched parentheses", function()
			local valid, err = graphql.validate_query("query { user(id: 1 { name } }")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("should detect unclosed strings", function()
			local valid, err = graphql.validate_query('query { user(name: "John) { id } }')
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("should handle escaped quotes in strings", function()
			local valid, err = graphql.validate_query('query { user(name: "John \\"Doe\\"") { id } }')
			assert.is_true(valid)
			assert.is_nil(err)
		end)

		it("should reject empty queries", function()
			local valid, err = graphql.validate_query("")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)

		it("should reject non-GraphQL text", function()
			local valid, err = graphql.validate_query("just some random text")
			assert.is_false(valid)
			assert.is_not_nil(err)
		end)
	end)
end)
