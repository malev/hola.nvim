if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("hola.nvim requires at least nvim-0.7.0.")
end

vim.api.nvim_create_user_command("HolaSend", function()
	require("hola").run_request_under_cursor()
end, {
	nargs = "*",
	desc = "Send request",
})


vim.api.nvim_create_user_command("HolaToggle", function()
	require("hola").toggle()
end, {
	nargs = "*",
	desc = "Toggle between response body and metadata",
})

vim.api.nvim_create_user_command("HolaClose", function()
	require("hola").close()
end, {
	nargs = "*",
	desc = "Close response window",
})

vim.api.nvim_create_user_command("HolaFormatJson", function()
	require("hola").toggle_json_format()
end, {
	nargs = "*",
	desc = "Toggle JSON formatting between formatted and raw views",
})




-- Debug commands for the new resolution system
vim.api.nvim_create_user_command("HolaDebug", function(opts)
	require("hola.resolution.debug").debug_command(opts)
end, {
	desc = "Debug variable resolution for the current HTTP request",
})

vim.api.nvim_create_user_command("HolaProviders", function(opts)
	require("hola.resolution.debug").provider_status_command(opts)
end, {
	desc = "Show status of all registered providers",
})
