local M = {}

local namespace = vim.api.nvim_create_namespace("hola_request_status")

-- Private: Get cursor position for virtual text
local function get_cursor_position()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	return cursor_pos[1] - 1, cursor_pos[2] -- Convert to 0-based line
end

-- Private: Show virtual text at cursor
local function set_virtual_text(message, highlight_group)
	local line, col = get_cursor_position()
	vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
	vim.api.nvim_buf_set_extmark(0, namespace, line, col, {
		virt_text = { { message, highlight_group or "Comment" } },
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

-- Public API
function M.show(message, highlight_group)
	set_virtual_text(message, highlight_group)
end

function M.clear()
	vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
end

function M.update(message, highlight_group)
	M.show(message, highlight_group)
end

-- Semantic loading messages
function M.show_loading(loading_type, details)
	local messages = {
		providers = "🔐Loading secrets from providers...",
		oauth_fetching = "🔐Fetching OAuth token from server...",
		oauth_cached = "🔐Using cached OAuth token" .. (details and " (" .. details .. ")" or ""),
		oauth_vault = "🔐Loading OAuth + Vault secrets...",
		sending = "⏳Sending...",
		vault = "🔐Loading Vault secrets...",
	}

	local message = messages[loading_type] or ("🔐Loading " .. loading_type .. "...")
	set_virtual_text(message, "Comment")
end

-- Semantic error messages
function M.show_error(error_type, details)
	local prefix = error_type == "oauth" and "❌OAuth Error: " or "❗Error: "
	local message = prefix .. (details or "Unknown error")
	set_virtual_text(message, "ErrorMsg")
end

-- Semantic success messages
function M.show_success(success_type, details)
	local messages = {
		response = function(status, elapsed_ms)
			local elapsed_text = elapsed_ms and string.format("%.0fms", elapsed_ms) or "?ms"
			return "✔️Response: " .. (status or "Unknown") .. " (" .. elapsed_text .. ")"
		end,
		oauth_token = function(env, expires_in)
			local env_text = env ~= "default" and " (" .. env .. ")" or ""
			local expires_text = expires_in and " - expires in " .. expires_in or ""
			return "✔️OAuth token acquired" .. env_text .. expires_text
		end,
	}

	local message
	if success_type == "response" and details then
		message = messages.response(details.status, details.elapsed_ms)
	elseif messages[success_type] then
		message = messages[success_type](details)
	else
		message = "✔️" .. success_type .. " successful"
	end

	set_virtual_text(message, "Comment")
end

-- OAuth-specific messages
function M.show_oauth_loading(cache_status, environment)
	local env_text = environment ~= "default" and " for " .. environment or ""

	if cache_status == "cached" then
		M.show_loading("oauth_cached", "expires in " .. (cache_status.expires_in or "unknown"))
	elseif cache_status == "mixed" then
		M.show_loading("oauth_vault")
	else
		M.show_loading("oauth_fetching")
	end
end

-- Provider error aggregation
function M.show_provider_errors(errors)
	if #errors == 1 then
		local err = errors[1]
		if err.variable:match("^OAUTH_TOKEN") then
			M.show_error("oauth", err.error)
		else
			M.show_error("provider", err.variable .. ": " .. err.error)
		end
	else
		local error_summary = {}
		for _, err in ipairs(errors) do
			table.insert(error_summary, err.variable)
		end
		M.show_error("providers", table.concat(error_summary, ", "))
	end
end

-- Request lifecycle messages
function M.show_request_sending()
	M.show_loading("sending")
end

function M.show_request_success(status, elapsed_ms)
	M.show_success("response", { status = status, elapsed_ms = elapsed_ms })
end

function M.show_parse_error()
	M.show_error("parse", "Failed to parse request")
end

-- Provider-specific messages for current codebase
function M.show_provider_loading()
	M.show_loading("providers")
end

function M.show_provider_error_list(provider_errors)
	local error_msg = "Provider errors: "
	for i, err in ipairs(provider_errors) do
		error_msg = error_msg .. err.variable .. " (" .. err.error .. ")"
		if i < #provider_errors then
			error_msg = error_msg .. ", "
		end
	end
	set_virtual_text("❗" .. error_msg, "ErrorMsg")
end

return M
