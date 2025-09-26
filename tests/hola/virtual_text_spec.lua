local virtual_text = require("hola.virtual_text")

-- Helper function to check virtual text content
local function get_virtual_text()
	local ns_id = vim.api.nvim_create_namespace("hola_request_status")
	local buf_id = vim.api.nvim_get_current_buf()
	local marks = vim.api.nvim_buf_get_extmarks(buf_id, ns_id, 0, -1, { details = true })
	if #marks > 0 then
		local mark = marks[1]
		if mark[4] and mark[4].virt_text then
			return mark[4].virt_text[1][1], mark[4].virt_text[1][2] -- text, highlight
		end
	end
	return nil, nil
end

-- Helper function to set cursor position (1-based)
local function set_cursor(line, col)
	vim.api.nvim_win_set_cursor(0, { line, col })
end

describe("virtual_text module", function()
	before_each(function()
		-- Create a buffer with some content
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"GET /api/test",
			"Content-Type: application/json",
			"",
			'{"test": true}'
		})
		set_cursor(1, 0)
		virtual_text.clear()
	end)

	after_each(function()
		virtual_text.clear()
	end)

	describe("basic API", function()
		it("should show basic message", function()
			virtual_text.show("test message", "Comment")
			local text, highlight = get_virtual_text()
			assert.equals("test message", text)
			assert.equals("Comment", highlight)
		end)

		it("should clear virtual text", function()
			virtual_text.show("test")
			virtual_text.clear()
			local text = get_virtual_text()
			assert.is_nil(text)
		end)

		it("should update virtual text", function()
			virtual_text.show("first message")
			virtual_text.update("second message", "ErrorMsg")
			local text, highlight = get_virtual_text()
			assert.equals("second message", text)
			assert.equals("ErrorMsg", highlight)
		end)

		it("should use default highlight group", function()
			virtual_text.show("test message")
			local _, highlight = get_virtual_text()
			assert.equals("Comment", highlight)
		end)
	end)

	describe("semantic loading messages", function()
		it("should show provider loading message", function()
			virtual_text.show_loading("providers")
			local text = get_virtual_text()
			assert.equals("🔐Loading secrets from providers...", text)
		end)

		it("should show sending message", function()
			virtual_text.show_loading("sending")
			local text = get_virtual_text()
			assert.equals("⏳Sending...", text)
		end)

		it("should show OAuth fetching message", function()
			virtual_text.show_loading("oauth_fetching")
			local text = get_virtual_text()
			assert.equals("🔐Fetching OAuth token from server...", text)
		end)

		it("should show OAuth cached message with details", function()
			virtual_text.show_loading("oauth_cached", "30m")
			local text = get_virtual_text()
			assert.equals("🔐Using cached OAuth token (30m)", text)
		end)

		it("should show vault loading message", function()
			virtual_text.show_loading("vault")
			local text = get_virtual_text()
			assert.equals("🔐Loading Vault secrets...", text)
		end)

		it("should show OAuth + Vault loading message", function()
			virtual_text.show_loading("oauth_vault")
			local text = get_virtual_text()
			assert.equals("🔐Loading OAuth + Vault secrets...", text)
		end)

		it("should show custom loading message", function()
			virtual_text.show_loading("custom_type")
			local text = get_virtual_text()
			assert.equals("🔐Loading custom_type...", text)
		end)
	end)

	describe("semantic error messages", function()
		it("should show basic error message", function()
			virtual_text.show_error("request", "Connection failed")
			local text, highlight = get_virtual_text()
			assert.equals("❗Error: Connection failed", text)
			assert.equals("ErrorMsg", highlight)
		end)

		it("should show OAuth error message", function()
			virtual_text.show_error("oauth", "Invalid client credentials")
			local text, highlight = get_virtual_text()
			assert.equals("❌OAuth Error: Invalid client credentials", text)
			assert.equals("ErrorMsg", highlight)
		end)

		it("should show error with default message", function()
			virtual_text.show_error("general")
			local text = get_virtual_text()
			assert.equals("❗Error: Unknown error", text)
		end)
	end)

	describe("semantic success messages", function()
		it("should show response success with status and timing", function()
			virtual_text.show_success("response", {status = 200, elapsed_ms = 150})
			local text = get_virtual_text()
			assert.equals("✔️Response: 200 (150ms)", text)
		end)

		it("should show response success with unknown timing", function()
			virtual_text.show_success("response", {status = 404})
			local text = get_virtual_text()
			assert.equals("✔️Response: 404 (?ms)", text)
		end)

		it("should show OAuth token success", function()
			virtual_text.show_success("oauth_token", "production")
			local text = get_virtual_text()
			assert.equals("✔️OAuth token acquired (production)", text)
		end)

		it("should show generic success message", function()
			virtual_text.show_success("custom_operation")
			local text = get_virtual_text()
			assert.equals("✔️custom_operation successful", text)
		end)
	end)

	describe("convenience functions", function()
		it("should show provider loading", function()
			virtual_text.show_provider_loading()
			local text = get_virtual_text()
			assert.equals("🔐Loading secrets from providers...", text)
		end)

		it("should show request sending", function()
			virtual_text.show_request_sending()
			local text = get_virtual_text()
			assert.equals("⏳Sending...", text)
		end)

		it("should show request success", function()
			virtual_text.show_request_success(201, 95)
			local text = get_virtual_text()
			assert.equals("✔️Response: 201 (95ms)", text)
		end)

		it("should show parse error", function()
			virtual_text.show_parse_error()
			local text, highlight = get_virtual_text()
			assert.equals("❗Error: Failed to parse request", text)
			assert.equals("ErrorMsg", highlight)
		end)

		it("should show provider error list", function()
			local errors = {
				{variable = "API_KEY", error = "not found"},
				{variable = "SECRET", error = "invalid format"}
			}
			virtual_text.show_provider_error_list(errors)
			local text, highlight = get_virtual_text()
			assert.equals("❗Provider errors: API_KEY (not found), SECRET (invalid format)", text)
			assert.equals("ErrorMsg", highlight)
		end)

		it("should show single provider error", function()
			local errors = {
				{variable = "DATABASE_URL", error = "connection refused"}
			}
			virtual_text.show_provider_error_list(errors)
			local text = get_virtual_text()
			assert.equals("❗Provider errors: DATABASE_URL (connection refused)", text)
		end)
	end)

	describe("provider error aggregation", function()
		it("should show single OAuth error", function()
			local errors = {
				{variable = "OAUTH_TOKEN_DEV", error = "expired"}
			}
			virtual_text.show_provider_errors(errors)
			local text = get_virtual_text()
			assert.equals("❌OAuth Error: expired", text)
		end)

		it("should show single provider error", function()
			local errors = {
				{variable = "API_SECRET", error = "not configured"}
			}
			virtual_text.show_provider_errors(errors)
			local text = get_virtual_text()
			assert.equals("❗Error: API_SECRET: not configured", text)
		end)

		it("should show multiple provider errors", function()
			local errors = {
				{variable = "API_KEY", error = "missing"},
				{variable = "SECRET_TOKEN", error = "invalid"},
				{variable = "DB_PASSWORD", error = "wrong"}
			}
			virtual_text.show_provider_errors(errors)
			local text = get_virtual_text()
			assert.equals("❗Error: API_KEY, SECRET_TOKEN, DB_PASSWORD", text)
		end)
	end)

	describe("OAuth loading messages", function()
		it("should show cached OAuth loading", function()
			virtual_text.show_oauth_loading("cached", "production")
			local text = get_virtual_text()
			assert.equals("🔐Using cached OAuth token (expires in unknown)", text)
		end)

		it("should show mixed OAuth/Vault loading", function()
			virtual_text.show_oauth_loading("mixed", "staging")
			local text = get_virtual_text()
			assert.equals("🔐Loading OAuth + Vault secrets...", text)
		end)

		it("should show OAuth fetching for default environment", function()
			virtual_text.show_oauth_loading("fetching", "default")
			local text = get_virtual_text()
			assert.equals("🔐Fetching OAuth token from server...", text)
		end)
	end)
end)