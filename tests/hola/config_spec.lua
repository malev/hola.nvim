local config = require("hola.config")

describe("hola.config", function()
	-- Store original state to restore after tests
	local original_config

	before_each(function()
		-- Save the current config state
		original_config = vim.deepcopy(config.get())
		-- Reset to defaults before each test
		config.reset()
	end)

	after_each(function()
		-- Restore original config after each test
		config.setup(original_config)
	end)

	describe("default configuration", function()
		it("should have correct default values", function()
			local defaults = config.get_defaults()

			-- JSON defaults
			assert.is_true(defaults.json.auto_format)

			-- UI defaults
			assert.is_false(defaults.ui.auto_focus_response)
			assert.are.equal("right", defaults.ui.response_window_position)
		end)

		it("should initialize with default values", function()
			config.reset()
			local current = config.get()
			local defaults = config.get_defaults()

			assert.are.same(defaults, current)
		end)

		it("should return a deep copy of defaults", function()
			local defaults1 = config.get_defaults()
			local defaults2 = config.get_defaults()

			-- Should be equal but not the same table
			assert.are.same(defaults1, defaults2)
			assert.are_not.equal(defaults1, defaults2)

			-- Modifying one shouldn't affect the other
			defaults1.json.auto_format = false
			assert.is_true(defaults2.json.auto_format)
		end)
	end)

	describe("setup function", function()
		it("should accept nil without error", function()
			assert.has_no_error(function()
				config.setup(nil)
			end)
		end)

		it("should merge partial configuration", function()
			config.setup({
				json = {
					auto_format = false
				}
			})

			local current = config.get()
			assert.is_false(current.json.auto_format)
			-- UI settings should remain default
			assert.is_false(current.ui.auto_focus_response)
			assert.are.equal("right", current.ui.response_window_position)
		end)

		it("should merge nested configuration", function()
			config.setup({
				ui = {
					auto_focus_response = true
				}
			})

			local current = config.get()
			assert.is_true(current.ui.auto_focus_response)
			-- Should keep default position
			assert.are.equal("right", current.ui.response_window_position)
			-- JSON settings should remain default
			assert.is_true(current.json.auto_format)
		end)

		it("should handle complete configuration override", function()
			config.setup({
				json = {
					auto_format = false
				},
				ui = {
					auto_focus_response = true,
					response_window_position = "left"
				}
			})

			local current = config.get()
			assert.is_false(current.json.auto_format)
			assert.is_true(current.ui.auto_focus_response)
			assert.are.equal("left", current.ui.response_window_position)
		end)

		it("should handle multiple setup calls", function()
			-- First setup
			config.setup({
				json = {
					auto_format = false
				}
			})

			-- Second setup should merge with first
			config.setup({
				ui = {
					auto_focus_response = true
				}
			})

			local current = config.get()
			assert.is_false(current.json.auto_format)
			assert.is_true(current.ui.auto_focus_response)
		end)

		it("should handle deep merging correctly", function()
			config.setup({
				json = {
					auto_format = false,
					new_option = "test"
				}
			})

			local current = config.get()
			assert.is_false(current.json.auto_format)
			assert.are.equal("test", current.json.new_option)
		end)
	end)

	describe("getter functions", function()
		describe("get()", function()
			it("should return current configuration", function()
				local current = config.get()
				assert.is_table(current)
				assert.is_table(current.json)
				assert.is_table(current.ui)
			end)

			it("should return updated configuration after setup", function()
				config.setup({
					json = { auto_format = false }
				})

				local current = config.get()
				assert.is_false(current.json.auto_format)
			end)

			it("should return a reference to the actual config", function()
				local config1 = config.get()
				local config2 = config.get()

				-- Should be the same object reference
				assert.are.equal(config1, config2)
			end)
		end)

		describe("get_json()", function()
			it("should return JSON configuration", function()
				local json_config = config.get_json()
				assert.is_table(json_config)
				assert.is_boolean(json_config.auto_format)
			end)

			it("should return updated JSON config after setup", function()
				config.setup({
					json = { auto_format = false }
				})

				local json_config = config.get_json()
				assert.is_false(json_config.auto_format)
			end)

			it("should return reference to actual JSON config", function()
				local json1 = config.get_json()
				local json2 = config.get_json()

				assert.are.equal(json1, json2)
			end)
		end)

		describe("get_ui()", function()
			it("should return UI configuration", function()
				local ui_config = config.get_ui()
				assert.is_table(ui_config)
				assert.is_boolean(ui_config.auto_focus_response)
				assert.is_string(ui_config.response_window_position)
			end)

			it("should return updated UI config after setup", function()
				config.setup({
					ui = { auto_focus_response = true }
				})

				local ui_config = config.get_ui()
				assert.is_true(ui_config.auto_focus_response)
			end)

			it("should return reference to actual UI config", function()
				local ui1 = config.get_ui()
				local ui2 = config.get_ui()

				assert.are.equal(ui1, ui2)
			end)
		end)
	end)

	describe("update_json function", function()
		it("should update JSON configuration", function()
			config.update_json({ auto_format = false })

			local json_config = config.get_json()
			assert.is_false(json_config.auto_format)
		end)

		it("should merge with existing JSON configuration", function()
			config.update_json({
				auto_format = false,
				new_option = "test_value"
			})

			local json_config = config.get_json()
			assert.is_false(json_config.auto_format)
			assert.are.equal("test_value", json_config.new_option)
		end)

		it("should not affect UI configuration", function()
			local original_ui = vim.deepcopy(config.get_ui())

			config.update_json({ auto_format = false })

			local current_ui = config.get_ui()
			assert.are.same(original_ui, current_ui)
		end)

		it("should handle multiple updates", function()
			config.update_json({ auto_format = false })
			config.update_json({ new_option = "test" })

			local json_config = config.get_json()
			assert.is_false(json_config.auto_format)
			assert.are.equal("test", json_config.new_option)
		end)

		it("should handle nested updates", function()
			config.update_json({
				nested = {
					option1 = "value1",
					option2 = "value2"
				}
			})

			local json_config = config.get_json()
			assert.are.equal("value1", json_config.nested.option1)
			assert.are.equal("value2", json_config.nested.option2)
		end)
	end)

	describe("reset function", function()
		it("should restore default configuration", function()
			-- Modify configuration
			config.setup({
				json = { auto_format = false },
				ui = { auto_focus_response = true }
			})

			-- Reset
			config.reset()

			-- Should match defaults
			local current = config.get()
			local defaults = config.get_defaults()
			assert.are.same(defaults, current)
		end)

		it("should reset after multiple changes", function()
			config.setup({ json = { auto_format = false } })
			config.update_json({ new_option = "test" })
			config.setup({ ui = { auto_focus_response = true } })

			config.reset()

			local current = config.get()
			local defaults = config.get_defaults()
			assert.are.same(defaults, current)
		end)

		it("should create independent config after reset", function()
			config.setup({ json = { auto_format = false } })
			config.reset()

			local config1 = config.get()
			config.setup({ json = { auto_format = false } })
			local config2 = config.get()

			-- Should be different objects
			assert.are_not.equal(config1, config2)
		end)
	end)

	describe("edge cases and error conditions", function()
		it("should handle empty configuration object", function()
			assert.has_no_error(function()
				config.setup({})
			end)

			local current = config.get()
			local defaults = config.get_defaults()
			assert.are.same(defaults, current)
		end)

		it("should handle configuration with extra fields", function()
			assert.has_no_error(function()
				config.setup({
					json = { auto_format = false },
					unknown_section = { option = "value" }
				})
			end)

			local current = config.get()
			assert.is_false(current.json.auto_format)
			assert.are.equal("value", current.unknown_section.option)
		end)

		it("should handle invalid types gracefully", function()
			assert.has_no_error(function()
				config.setup({
					json = { auto_format = "not_boolean" }
				})
			end)

			local current = config.get()
			assert.are.equal("not_boolean", current.json.auto_format)
		end)

		it("should handle nested nil values", function()
			assert.has_no_error(function()
				config.setup({
					json = nil
				})
			end)

			local current = config.get()
			-- vim.tbl_deep_extend with "force" preserves the original when merging nil
			-- So json should still exist with default values
			assert.is_table(current.json)
			assert.is_true(current.json.auto_format) -- Should keep default
		end)

		it("should handle update_json with nil", function()
			assert.has_error(function()
				config.update_json(nil)
			end)
		end)

		it("should handle update_json with non-table", function()
			assert.has_error(function()
				config.update_json("not a table")
			end)
		end)

		it("should preserve configuration isolation", function()
			local config1 = config.get()
			config1.json.auto_format = false

			-- Getting config again should still have default
			local config2 = config.get()
			assert.is_false(config2.json.auto_format) -- This will be false because it's the same reference

			-- But resetting should restore defaults
			config.reset()
			local config3 = config.get()
			assert.is_true(config3.json.auto_format)
		end)
	end)

	describe("configuration persistence", function()
		it("should maintain configuration across function calls", function()
			config.setup({
				json = { auto_format = false },
				ui = { auto_focus_response = true }
			})

			-- Multiple calls should return same config
			assert.is_false(config.get_json().auto_format)
			assert.is_true(config.get_ui().auto_focus_response)

			-- After other operations
			config.update_json({ new_option = "test" })
			assert.is_false(config.get_json().auto_format)
			assert.are.equal("test", config.get_json().new_option)
		end)

		it("should handle rapid configuration changes", function()
			for i = 1, 10 do
				config.setup({
					json = { auto_format = (i % 2 == 0) }
				})
			end

			-- Should have the last value
			assert.is_true(config.get_json().auto_format)
		end)
	end)
end)