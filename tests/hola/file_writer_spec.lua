local file_writer = require("hola.file_writer")

describe("hola.file_writer", function()
	local temp_dir
	local temp_file

	before_each(function()
		-- Create a temporary directory for testing
		temp_dir = vim.fn.tempname()
		vim.fn.mkdir(temp_dir, "p")
		temp_file = temp_dir .. "/test_output.txt"
	end)

	after_each(function()
		-- Clean up temporary directory and files
		if vim.fn.isdirectory(temp_dir) == 1 then
			vim.fn.delete(temp_dir, "rf")
		end
	end)

	describe("write_file", function()
		it("writes text content to a file", function()
			local content = "Hello, World!"
			local ok, path = file_writer.write_file(temp_file, content)

			assert.is_true(ok)
			assert.are.equal(vim.fn.expand(temp_file), path)

			-- Verify file exists and contains correct content
			local file = io.open(temp_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal(content, read_content)
		end)

		it("writes binary content to a file", function()
			-- Create some binary content (e.g., a simple PNG header)
			local binary_content = "\137\080\078\071\013\010\026\010"
			local ok, path = file_writer.write_file(temp_file, binary_content)

			assert.is_true(ok)

			-- Verify file exists and contains correct binary content
			local file = io.open(temp_file, "rb")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal(binary_content, read_content)
		end)

		it("creates parent directories if they don't exist", function()
			local nested_file = temp_dir .. "/nested/dir/file.txt"
			local content = "Nested file content"
			local ok, path = file_writer.write_file(nested_file, content)

			assert.is_true(ok)

			-- Verify file exists
			assert.are.equal(1, vim.fn.filereadable(nested_file))

			-- Verify content
			local file = io.open(nested_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal(content, read_content)
		end)

		it("handles empty content", function()
			local ok, path = file_writer.write_file(temp_file, "")

			assert.is_true(ok)

			-- Verify file exists and is empty
			local file = io.open(temp_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal("", read_content)
		end)

		it("handles nil content as empty", function()
			local ok, path = file_writer.write_file(temp_file, nil)

			assert.is_true(ok)

			-- Verify file exists and is empty
			local file = io.open(temp_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal("", read_content)
		end)

		it("returns error for empty file path", function()
			local ok, err = file_writer.write_file("", "content")

			assert.is_false(ok)
			assert.is_not_nil(err)
			assert.is_string(err)
		end)

		it("expands ~ in file paths", function()
			-- Skip this test if $HOME is not set
			if not vim.env.HOME then
				pending("HOME environment variable not set")
				return
			end

			local home_file = "~/test_hola_output.txt"
			local content = "Home directory test"
			local ok, path = file_writer.write_file(home_file, content)

			assert.is_true(ok)

			-- Clean up
			local expanded_path = vim.fn.expand(home_file)
			if vim.fn.filereadable(expanded_path) == 1 then
				vim.fn.delete(expanded_path)
			end
		end)
	end)

	describe("save_response", function()
		it("saves response body to a file", function()
			local response = {
				status = 200,
				body = '{"message": "success"}',
				headers = {},
			}

			local ok, path = file_writer.save_response(response, temp_file)

			assert.is_true(ok)

			-- Verify content
			local file = io.open(temp_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal(response.body, read_content)
		end)

		it("handles response with no body", function()
			local response = {
				status = 204,
				headers = {},
			}

			local ok, path = file_writer.save_response(response, temp_file)

			assert.is_true(ok)

			-- Verify file is empty
			local file = io.open(temp_file, "r")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal("", read_content)
		end)

		it("handles binary response (image data)", function()
			-- Simulate an image response with binary data
			local response = {
				status = 200,
				body = "\137\080\078\071\013\010\026\010", -- PNG header
				headers = { ["content-type"] = "image/png" },
			}

			local ok, path = file_writer.save_response(response, temp_file)

			assert.is_true(ok)

			-- Verify binary content is preserved
			local file = io.open(temp_file, "rb")
			local read_content = file:read("*all")
			file:close()

			assert.are.equal(response.body, read_content)
		end)

		it("returns error for invalid response", function()
			local ok, err = file_writer.save_response(nil, temp_file)

			assert.is_false(ok)
			assert.is_not_nil(err)
			assert.is_string(err)
		end)

		it("returns error for invalid response type", function()
			local ok, err = file_writer.save_response("not a table", temp_file)

			assert.is_false(ok)
			assert.is_not_nil(err)
			assert.is_string(err)
		end)
	end)
end)
