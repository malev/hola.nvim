local M = {}

local DEFAULT_CONFIG = {
	json = {
		auto_format = true,
	},
	ui = {
		auto_focus_response = false,
		response_window_position = "right",
	},
	log = {
		level = "WARN",
	},
}

local user_config = vim.deepcopy(DEFAULT_CONFIG)

function M.setup(opts)
	if opts then
		user_config = vim.tbl_deep_extend("force", user_config, opts)
	end

	if opts and opts.log and opts.log.level then
		local log = require("hola.log")
		log.set_level(user_config.log.level)
	end
end

--- Get current configuration
-- @return (table) Current configuration
function M.get()
	return user_config
end

--- Get JSON-specific configuration
-- @return (table) JSON configuration options
function M.get_json()
	return user_config.json
end

function M.get_ui()
	return user_config.ui
end

function M.get_log()
	return user_config.log
end

function M.update_json(json_opts)
	user_config.json = vim.tbl_deep_extend("force", user_config.json, json_opts)
end

function M.update_log(log_opts)
	if log_opts.level then
		user_config.log.level = log_opts.level
		local log = require("hola.log")
		log.set_level(log_opts.level)
	end
end

--- Reset configuration to defaults
function M.reset()
	user_config = vim.deepcopy(DEFAULT_CONFIG)
end

--- Get default configuration (for reference)
-- @return (table) Default configuration
function M.get_defaults()
	return vim.deepcopy(DEFAULT_CONFIG)
end

return M
