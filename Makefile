test: deps/plenary.nvim
	nvim --headless -u scripts/minimal.lua -c "PlenaryBustedDirectory ./tests {minimal_init='./scripts/minimal.lua'}"

lint:
	luacheck lua/hola plugin/ spec/

deps/plenary.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim $@
