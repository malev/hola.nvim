describe("dotnenv", function()
	local dotenv = require("hola.dotenv")
	describe("parse_dotenv_file", function()
		local original_readfile -- Variable to store the original function

		-- Mock vim.fn.readfile before each test
		before_each(function()
			original_readfile = vim.fn.readfile -- Store the original
			-- Replace with our mock function
			vim.fn.readfile = function(filepath_arg)
				-- This mock checks the path and returns specific content for our tests
				if filepath_arg == "/fake/path/to/.env" then
					-- Return the predefined content for the current test (set within the 'it' block)
					-- This variable 'mock_file_content' needs to be accessible; Lua closures help.
					-- We'll define 'mock_file_content' within each 'it' block or a 'before_each' specific setup.
					if _G.current_mock_file_content then
						return _G.current_mock_file_content
					else
						error("Mock vim.fn.readfile called but no mock content set!")
					end
				else
					-- For any other path, simulate file not found or error
					-- Returning false simulates pcall failing, returning nil simulates empty file?
					-- Let's return an error message string, as pcall would capture it.
					return { "Error: Mock file not found: " .. filepath_arg } -- This will make pcall return false
				end
			end
		end)

		-- Restore the original vim.fn.readfile after each test
		after_each(function()
			vim.fn.readfile = original_readfile -- Restore the original
			_G.current_mock_file_content = nil -- Clean up global test variable
		end)

		it("should parse basic KEY=VALUE pairs", function()
			-- 1. Define the simulated file content for this test
			_G.current_mock_file_content = {
				"VAR1=value1",
				"VAR2=value2",
			}

			-- 2. Define the expected output table
			local expected = {
				VAR1 = "value1",
				VAR2 = "value2",
			}

			-- 3. Call the function under test with a path our mock recognizes
			local actual = dotenv.parse_dotenv_file("/fake/path/to/.env")

			-- 4. Assert equality (use assert.same for deep table comparison)
			assert.same(expected, actual)
		end)

		it("should ignore comments and blank lines", function()
			_G.current_mock_file_content = {
				"# This is a comment",
				"KEY_A=valueA",
				"",
				"KEY_B=valueB",
				" ", -- Line with only whitespace
				"# Another comment",
			}
			local expected = {
				KEY_A = "valueA",
				KEY_B = "valueB",
			}
			local actual = dotenv.parse_dotenv_file("/fake/path/to/.env")
			assert.same(expected, actual)
		end)

		it("should trim whitespace from keys and values", function()
			_G.current_mock_file_content = {
				"  SPACED_KEY = value_with_space  ",
				"NORMAL_KEY= normal_value ",
				"KEY_WITH_SPACE = value with internal space",
			}
			local expected = {
				SPACED_KEY = "value_with_space",
				NORMAL_KEY = "normal_value",
				KEY_WITH_SPACE = "value with internal space",
			}
			local actual = dotenv.parse_dotenv_file("/fake/path/to/.env")
			assert.same(expected, actual)
		end)

		it("should handle empty values", function()
			_G.current_mock_file_content = {
				"EMPTY_VALUE=",
				"KEY_AFTER=something",
				"EMPTY_WITH_SPACE= ", -- Value is a single space after trimming
			}
			local expected = {
				EMPTY_VALUE = "",
				KEY_AFTER = "something",
				EMPTY_WITH_SPACE = "", -- Trim removes the space
			}
			local actual = dotenv.parse_dotenv_file("/fake/path/to/.env")
			assert.same(expected, actual)
		end)
	end)
end)
