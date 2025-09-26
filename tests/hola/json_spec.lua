local json = require("hola.json")

describe("JSON module", function()
	describe("format", function()
		it("should format simple objects", function()
			local input = '{"name":"John","age":30}'
			local expected = '{\n  "age": 30,\n  "name": "John"\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should format nested objects", function()
			local input = '{"user":{"name":"John","address":{"city":"NYC","zip":"10001"}}}'
			local expected =
				'{\n  "user": {\n    "address": {\n      "city": "NYC",\n      "zip": "10001"\n    },\n    "name": "John"\n  }\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should format simple arrays compactly", function()
			local input = '{"numbers":[1,2,3,4]}'
			local expected = '{\n  "numbers": [1, 2, 3, 4]\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should expand large arrays", function()
			local input = '{"numbers":[1,2,3,4,5,6,7,8]}'
			local expected = '{\n  "numbers": [\n    1,\n    2,\n    3,\n    4,\n    5,\n    6,\n    7,\n    8\n  ]\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should expand arrays with objects", function()
			local input = '[{"name":"John"},{"name":"Jane"}]'
			local expected = '[\n  {\n    "name": "John"\n  },\n  {\n    "name": "Jane"\n  }\n]'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should handle empty objects and arrays", function()
			local input = '{"empty_obj":{},"empty_array":[]}'
			local expected = '{\n  "empty_array": [],\n  "empty_obj": {}\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should handle different data types", function()
			local input = '{"string":"hello","number":42,"boolean":true,"null_value":null}'
			local expected = '{\n  "boolean": true,\n  "null_value": null,\n  "number": 42,\n  "string": "hello"\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should escape special characters in strings", function()
			local input = '{"text":"Hello\\nWorld\\t\\"Quote\\""}'
			local expected = '{\n  "text": "Hello\\nWorld\\t\\"Quote\\""\n}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should respect custom indent size", function()
			local input = '{"name":"John","age":30}'
			local expected = '{\n    "age": 30,\n    "name": "John"\n}'

			local result, err = json.format(input, { indent_size = 4 })
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should sort keys when requested", function()
			local input = '{"zebra":"last","alpha":"first","beta":"second"}'
			local expected = '{\n  "alpha": "first",\n  "beta": "second",\n  "zebra": "last"\n}'

			local result, err = json.format(input, { sort_keys = true })
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should handle compact_arrays=false", function()
			local input = '{"numbers":[1,2,3]}'
			local expected = '{\n  "numbers": [\n    1,\n    2,\n    3\n  ]\n}'

			local result, err = json.format(input, { compact_arrays = false })
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should return error for invalid JSON", function()
			local input = '{"invalid": json}'

			local result, err = json.format(input)
			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("Invalid JSON", err)
		end)

		it("should return error for empty input", function()
			local result, err = json.format("")
			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("Empty JSON string", err)
		end)

		it("should return error for nil input", function()
			local result, err = json.format(nil)
			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("Empty JSON string", err)
		end)
	end)

	describe("minify", function()
		it("should minify formatted JSON", function()
			local input = '{\n  "name": "John",\n  "age": 30\n}'
			local expected = '{"age":30,"name":"John"}'

			local result, err = json.minify(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should handle already minified JSON", function()
			local input = '{"name":"John","age":30}'
			local expected = '{"age":30,"name":"John"}'

			local result, err = json.minify(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should return error for invalid JSON", function()
			local input = '{"invalid": json}'

			local result, err = json.minify(input)
			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("Invalid JSON", err)
		end)

		it("should return error for empty input", function()
			local result, err = json.minify("")
			assert.is_nil(result)
			assert.is_not_nil(err)
			assert.matches("Empty JSON string", err)
		end)
	end)

	describe("get_default_config", function()
		it("should return default configuration", function()
			local config = json.get_default_config()

			assert.is_table(config)
			assert.are.equal(2, config.indent_size)
			assert.is_true(config.sort_keys)
			assert.is_true(config.compact_arrays)
			assert.are.equal(5, config.max_array_length)
		end)

		it("should return a copy of defaults", function()
			local config1 = json.get_default_config()
			local config2 = json.get_default_config()

			config1.indent_size = 8
			assert.are.equal(2, config2.indent_size) -- Should not be affected
		end)
	end)

	describe("edge cases", function()
		it("should handle very deeply nested structures", function()
			local input = '{"a":{"b":{"c":{"d":{"e":"deep"}}}}}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.is_string(result)
			assert.matches("deep", result)
		end)

		it("should handle mixed array content", function()
			local input = '[1,"string",{"object":"value"},true,null]'
			local expected = '[\n  1,\n  "string",\n  {\n    "object": "value"\n  },\n  true,\n  null\n]'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.are.equal(expected, result)
		end)

		it("should handle unicode characters", function()
			local input = '{"unicode":"こんにちは","emoji":"🎉"}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.matches("こんにちは", result)
			assert.matches("🎉", result)
		end)

		it("should handle numbers with decimals and scientific notation", function()
			local input = '{"pi":3.14159,"large":1.23e10,"small":1.23e-10}'

			local result, err = json.format(input)
			assert.is_nil(err)
			assert.matches("3.14159", result)
			assert.matches("1.23e", result) -- Scientific notation
		end)
	end)
end)

