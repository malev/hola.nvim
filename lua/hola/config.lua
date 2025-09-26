local M = {}

--- Default configuration for hola.nvim
local DEFAULT_CONFIG = {
	-- JSON formatting options
	json = {
		auto_format = true, -- Automatically format JSON responses
		enable_folding = true, -- Enable JSON folding in buffer
	},
	-- UI options
	ui = {
		auto_focus_response = false, -- Focus response window after request
		response_window_position = "right", -- Position of response window
	},
	-- Vault integration options
	vault = {
		enabled = false, -- Enable vault secret integration
	},
}

--- Current user configuration
local user_config = vim.deepcopy(DEFAULT_CONFIG)

--- Setup function to configure hola.nvim
-- @param opts (table|nil) User configuration options
function M.setup(opts)
	if opts then
		user_config = vim.tbl_deep_extend("force", user_config, opts)
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

--- Get UI-specific configuration
-- @return (table) UI configuration options
function M.get_ui()
	return user_config.ui
end

--- Get vault-specific configuration
-- @return (table) Vault configuration options
function M.get_vault()
	return user_config.vault
end

--- Update JSON configuration
-- @param json_opts (table) JSON configuration to merge
function M.update_json(json_opts)
	user_config.json = vim.tbl_deep_extend("force", user_config.json, json_opts)
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