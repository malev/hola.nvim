if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("hola.nvim requires at least nvim-0.7.0.")
end

vim.api.nvim_create_user_command("HolaSend", function()
	require("hola").run_request_under_cursor()
end, {
	nargs = "*",
	desc = "Send request",
})

vim.api.nvim_create_user_command("HolaSendSelected", function()
	require("hola").run_selected_request()
end, {
	nargs = "*",
	desc = "Send selected request",
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

vim.api.nvim_create_user_command("HolaValidateJson", function()
	require("hola").validate_json()
end, {
	nargs = "*",
	desc = "Validate current JSON response",
})

vim.api.nvim_create_user_command("HolaCloseWindow", function()
	vim.print("Deprecated. Try :HolaToggle instead.", vim.log.levels.WARN)
end, {
	nargs = "*",
	desc = "Close window",
})

vim.api.nvim_create_user_command("HolaShowWindow", function()
	vim.print("Deprecated. Try :HolaToggle instead.", vim.log.levels.WARN)
end, {
	nargs = "*",
	desc = "Show window",
})

vim.api.nvim_create_user_command("HolaMaximizeWindow", function()
	vim.print("Deprecated. Try :HolaToggle instead.", vim.log.levels.WARN)
end, {
	nargs = "*",
	desc = "Maximize window",
})
