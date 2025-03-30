if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("hola.nvim requires at least nvim-0.7.0.")
end

vim.api.nvim_create_user_command("HolaSend", function()
	require("hola").send_selected()
end, {
	nargs = "*",
	desc = "Send selected",
})

vim.api.nvim_create_user_command("HolaCloseWindow", function()
	require("hola").close_window()
end, {
	nargs = "*",
	desc = "Close window",
})

vim.api.nvim_create_user_command("HolaShowWindow", function()
	require("hola").show_window()
end, {
	nargs = "*",
	desc = "Close window",
})

vim.api.nvim_create_user_command("HolaMaximizeWindow", function()
	require("hola").maximize_window()
end, {
	nargs = "*",
	desc = "Close window",
})
