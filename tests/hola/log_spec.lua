local log = require("hola.log")

describe("hola.log", function()
	before_each(function()
		log.clear()
		log.set_level("TRACE")
		vim.wait(50)
	end)

	after_each(function()
		log.clear()
	end)

	describe("log levels", function()
		it("should set and get log level by name", function()
			assert.is_true(log.set_level("INFO"))
			assert.equals(log.levels.INFO, log.get_level())
			assert.equals("INFO", log.get_level_name())
		end)

		it("should set and get log level by number", function()
			assert.is_true(log.set_level(log.levels.DEBUG))
			assert.equals(log.levels.DEBUG, log.get_level())
			assert.equals("DEBUG", log.get_level_name())
		end)

		it("should reject invalid log level names", function()
			local success, error = log.set_level("INVALID")
			assert.is_false(success)
			assert.is_not_nil(error)
		end)

		it("should reject invalid log level numbers", function()
			local success, error = log.set_level(999)
			assert.is_false(success)
			assert.is_not_nil(error)
		end)

		it("should be case insensitive for level names", function()
			assert.is_true(log.set_level("debug"))
			assert.equals(log.levels.DEBUG, log.get_level())
		end)
	end)

	describe("logging functions", function()
		it("should write log entries to file", function()
			log.clear()
			vim.wait(50)
			log.info("Test message")
			vim.wait(50)

			local content = vim.fn.readfile(log.get_filename())
			assert.is_true(#content > 0)
			local has_test_message = false
			for _, line in ipairs(content) do
				if line:match("Test message") and line:match("%[INFO%]") then
					has_test_message = true
					break
				end
			end
			assert.is_true(has_test_message)
		end)

		it("should respect log level filtering", function()
			log.set_level("ERROR")
			log.info("Should not appear")
			log.error("Should appear")
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			local log_text = table.concat(content, "\n")
			assert.is_false(log_text:match("Should not appear") ~= nil)
			assert.is_true(log_text:match("Should appear") ~= nil)
		end)

		it("should include timestamp in log entries", function()
			log.info("Test")
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			assert.is_true(content[1]:match("%d%d%d%d%-%d%d%-%d%d") ~= nil)
		end)

		it("should include source file and line number", function()
			log.info("Test")
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			assert.is_true(content[1]:match("%[.+:%d+%]") ~= nil)
		end)
	end)

	describe("secret redaction", function()
		it("should redact API keys", function()
			log.info("api_key=1234567890abcdefgh")
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			local log_text = table.concat(content, "\n")
			assert.is_true(log_text:match("1234%*%*%*%*fgh") ~= nil)
			assert.is_false(log_text:match("1234567890abcdefgh") ~= nil)
		end)
	end)

	describe("file operations", function()
		it("should get default log filename", function()
			local filename = log.get_filename()
			assert.is_not_nil(filename)
			assert.is_true(filename:match("hola%.log$") ~= nil)
		end)

		it("should clear log file", function()
			log.info("Before clear")
			vim.wait(50)

			local before_content = vim.fn.readfile(log.get_filename())
			assert.is_true(#before_content > 0)

			log.set_level("OFF")
			assert.is_true(log.clear())
			vim.wait(50)

			local stat = vim.loop.fs_stat(log.get_filename())
			assert.is_true(stat == nil or stat.size == 0)
		end)
	end)

	describe("log messages", function()
		it("should handle tables in log messages", function()
			log.info("Data:", { foo = "bar", baz = 123 })
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			local log_text = table.concat(content, "\n")
			assert.is_true(log_text:match("foo") ~= nil)
			assert.is_true(log_text:match("bar") ~= nil)
		end)

		it("should handle multiple arguments", function()
			log.info("Message", "with", "multiple", "parts")
			vim.wait(100)

			local content = vim.fn.readfile(log.get_filename())
			local log_text = table.concat(content, "\n")
			assert.is_true(log_text:match("Message with multiple parts") ~= nil)
		end)
	end)

	describe("log level hierarchy", function()
		it("should have correct level values", function()
			assert.equals(0, log.levels.TRACE)
			assert.equals(1, log.levels.DEBUG)
			assert.equals(2, log.levels.INFO)
			assert.equals(3, log.levels.WARN)
			assert.equals(4, log.levels.ERROR)
			assert.equals(5, log.levels.OFF)
		end)

		it("TRACE level should log everything", function()
			log.clear()
			vim.wait(50)
			log.set_level("TRACE")
			log.trace("trace")
			log.debug("debug")
			log.info("info")
			log.warn("warn")
			log.error("error")
			vim.wait(50)

			local content = vim.fn.readfile(log.get_filename())
			assert.is_true(#content >= 5)
		end)
	end)
end)
