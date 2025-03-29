if vim.fn.has("nvim-0.7.0") ~= 1 then
	vim.api.nvim_err_writeln("hola.nvim requires at least nvim-0.7.0.")
end

vim.api.nvim_create_user_command("HolaSend", function()
	require("hola").send_selected()
end, {
	nargs = "*",
	desc = "Send selected",
})

vim.api.nvim_create_user_command("HolaHide", function()
	require("hola").hide()
end, {
	nargs = "*",
	desc = "Hide window",
})

vim.api.nvim_create_user_command("HolaToggle", function()
	require("hola").toggle()
end, {
	nargs = "*",
	desc = "Toggle window",
})
