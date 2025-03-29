describe("hola.nvim", function()
	local hola = require("hola")

	it("should add numbers correctly", function()
		assert.are.same(5, hola.add_numbers(2, 3))
		assert.are.same(0, hola.add_numbers(-1, 1))
	end)

	it("should greet a person correctly", function()
		assert.are.same("Hello, Alice!", hola.greet("Alice"))
		assert.are.same("Hello, Bob!", hola.greet("Bob"))
	end)
end)
