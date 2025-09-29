--- Tests for the refs provider
--- Tests the refs provider functionality including file parsing, variable resolution, and caching

local refs_provider = require('hola.resolution.providers.refs')

describe("hola refs provider", function()
  local provider

  before_each(function()
    provider = refs_provider.new()
    -- Clear any existing cache
    provider:cache_clear()
  end)

  after_each(function()
    if provider then
      provider:cleanup()
    end
  end)

  describe("provider interface", function()
    it("should implement required methods", function()
      assert.is_function(provider.can_handle)
      assert.is_function(provider.resolve)
      assert.is_function(provider.load_config)
      assert.is_function(provider.initialize)
    end)

    it("should have correct metadata", function()
      local metadata = provider:get_metadata()
      assert.equals("refs", metadata.name)
      assert.equals("Variable aliases and shortcuts to other providers", metadata.description)
      assert.is_table(metadata.config_files)
      assert.is_true(vim.tbl_contains(metadata.config_files, "refs"))
      assert.is_false(metadata.requires_network)
    end)

    it("should validate interface correctly", function()
      local valid, error = provider:validate_interface()
      assert.is_true(valid)
      assert.is_nil(error)
    end)
  end)

  describe("can_handle", function()
    it("should handle refs provider format", function()
      assert.is_true(provider:can_handle("{{refs:API_KEY}}"))
      assert.is_true(provider:can_handle("{{refs:DB_PASSWORD}}"))
      assert.is_true(provider:can_handle("{{refs:SOME_ALIAS}}"))
    end)

    it("should not handle other provider formats", function()
      assert.is_false(provider:can_handle("{{env:API_KEY}}"))
      assert.is_false(provider:can_handle("{{vault:secret/path#field}}"))
      assert.is_false(provider:can_handle("{{oauth:service}}"))
      assert.is_false(provider:can_handle("{{API_KEY}}"))
      assert.is_false(provider:can_handle("API_KEY"))
    end)

    it("should not handle malformed variables", function()
      assert.is_false(provider:can_handle("{{refs:}}"))
      assert.is_false(provider:can_handle("{{refs}}"))
      assert.is_false(provider:can_handle("{refs:API_KEY}"))
      assert.is_false(provider:can_handle("refs:API_KEY"))
    end)
  end)

  describe("resolve", function()
    local original_getcwd
    local original_fs_stat
    local original_readfile

    before_each(function()
      -- Mock vim.fn.getcwd
      original_getcwd = vim.fn.getcwd
      vim.fn.getcwd = function()
        return "/test/path"
      end

      -- Mock vim.loop.fs_stat
      original_fs_stat = vim.loop.fs_stat
      vim.loop.fs_stat = function(path)
        if path == "/test/path/refs" then
          return { type = "file", mtime = { sec = 1234567890 } }
        end
        return nil
      end

      -- Mock vim.fn.readfile
      original_readfile = vim.fn.readfile
      vim.fn.readfile = function(path)
        if path == "/test/path/refs" then
          return {
            "# API credentials",
            "API_KEY={{vault:secret/app#api_key}}",
            "DB_PASSWORD={{vault:database/prod#password}}",
            "",
            "# OAuth services",
            "GITHUB_TOKEN={{oauth:github}}",
            "SLACK_TOKEN={{oauth:slack}}",
            "",
            "# Environment shortcuts",
            "DEBUG_MODE={{env:DEBUG}}",
            "BASE_URL={{env:API_BASE_URL}}",
            "",
            "# Complex nested reference",
            "AUTH_HEADER=Bearer {{oauth:my_service}}"
          }
        end
        error("File not found: " .. path)
      end
    end)

    after_each(function()
      -- Restore original functions
      vim.fn.getcwd = original_getcwd
      vim.loop.fs_stat = original_fs_stat
      vim.fn.readfile = original_readfile
    end)

    it("should resolve simple alias to provider reference", function()
      local value, error = provider:resolve("refs:API_KEY")
      assert.is_nil(error)
      assert.equals("{{vault:secret/app#api_key}}", value)
    end)

    it("should resolve OAuth alias", function()
      local value, error = provider:resolve("refs:GITHUB_TOKEN")
      assert.is_nil(error)
      assert.equals("{{oauth:github}}", value)
    end)

    it("should resolve environment alias", function()
      local value, error = provider:resolve("refs:DEBUG_MODE")
      assert.is_nil(error)
      assert.equals("{{env:DEBUG}}", value)
    end)

    it("should resolve complex reference with spaces", function()
      local value, error = provider:resolve("refs:AUTH_HEADER")
      assert.is_nil(error)
      assert.equals("Bearer {{oauth:my_service}}", value)
    end)

    it("should handle identifier without refs: prefix", function()
      local value, error = provider:resolve("API_KEY")
      assert.is_nil(error)
      assert.equals("{{vault:secret/app#api_key}}", value)
    end)

    it("should return error for non-existent alias", function()
      local value, error = provider:resolve("refs:NONEXISTENT")
      assert.is_nil(value)
      assert.is_not_nil(error)
      assert.is_true(string.find(error, "not found") ~= nil)
    end)

    it("should return error for empty variable name", function()
      local value, error = provider:resolve("refs:")
      assert.is_nil(value)
      assert.is_not_nil(error)
      assert.is_true(string.find(error, "Empty variable name") ~= nil)
    end)

    it("should cache resolved values", function()
      -- First resolve should hit the file
      local value1, error1 = provider:resolve("refs:API_KEY")
      assert.is_nil(error1)
      assert.equals("{{vault:secret/app#api_key}}", value1)

      -- Mock file to return different content
      vim.fn.readfile = function(path)
        return { "API_KEY={{env:CHANGED}}" }
      end

      -- Second resolve should use cache (same value)
      local value2, error2 = provider:resolve("refs:API_KEY")
      assert.is_nil(error2)
      assert.equals("{{vault:secret/app#api_key}}", value2) -- Should be cached
    end)
  end)

  describe("file parsing", function()
    local original_getcwd
    local original_fs_stat
    local original_readfile

    before_each(function()
      original_getcwd = vim.fn.getcwd
      original_fs_stat = vim.loop.fs_stat
      original_readfile = vim.fn.readfile

      vim.fn.getcwd = function() return "/test" end
      vim.loop.fs_stat = function(path)
        if path == "/test/refs" then
          return { type = "file", mtime = { sec = 1234567890 } }
        end
        return nil
      end
    end)

    after_each(function()
      vim.fn.getcwd = original_getcwd
      vim.loop.fs_stat = original_fs_stat
      vim.fn.readfile = original_readfile
    end)

    it("should parse basic alias=target pairs", function()
      vim.fn.readfile = function(path)
        return {
          "API_KEY={{vault:secret/app#api_key}}",
          "DB_PASS={{vault:db#password}}"
        }
      end

      local value1, error1 = provider:resolve("API_KEY")
      assert.is_nil(error1)
      assert.equals("{{vault:secret/app#api_key}}", value1)

      local value2, error2 = provider:resolve("DB_PASS")
      assert.is_nil(error2)
      assert.equals("{{vault:db#password}}", value2)
    end)

    it("should ignore comments and blank lines", function()
      vim.fn.readfile = function(path)
        return {
          "# This is a comment",
          "",
          "API_KEY={{vault:secret/app#api_key}}",
          "  # Another comment",
          "",
          "DB_PASS={{vault:db#password}}"
        }
      end

      local value1, error1 = provider:resolve("API_KEY")
      assert.is_nil(error1)
      assert.equals("{{vault:secret/app#api_key}}", value1)

      local value2, error2 = provider:resolve("DB_PASS")
      assert.is_nil(error2)
      assert.equals("{{vault:db#password}}", value2)
    end)

    it("should trim whitespace from keys and values", function()
      vim.fn.readfile = function(path)
        return {
          "  API_KEY  =  {{vault:secret/app#api_key}}  ",
          "DB_PASS={{vault:db#password}}"
        }
      end

      local value, error = provider:resolve("API_KEY")
      assert.is_nil(error)
      assert.equals("{{vault:secret/app#api_key}}", value)
    end)

    it("should handle quoted values", function()
      vim.fn.readfile = function(path)
        return {
          'API_KEY="{{vault:secret/app#api_key}}"',
          "DB_PASS='{{vault:db#password}}'"
        }
      end

      local value1, error1 = provider:resolve("API_KEY")
      assert.is_nil(error1)
      assert.equals("{{vault:secret/app#api_key}}", value1)

      local value2, error2 = provider:resolve("DB_PASS")
      assert.is_nil(error2)
      assert.equals("{{vault:db#password}}", value2)
    end)

    it("should handle no refs file gracefully", function()
      vim.loop.fs_stat = function(path) return nil end

      local value, error = provider:resolve("API_KEY")
      assert.is_nil(value)
      assert.is_not_nil(error)
      assert.is_true(string.find(error, "not found") ~= nil)
    end)
  end)

  describe("validation", function()
    local original_getcwd
    local original_fs_stat
    local original_readfile

    before_each(function()
      original_getcwd = vim.fn.getcwd
      original_fs_stat = vim.loop.fs_stat
      original_readfile = vim.fn.readfile

      vim.fn.getcwd = function() return "/test" end
      vim.loop.fs_stat = function(path)
        if path == "/test/refs" then
          return { type = "file", mtime = { sec = 1234567890 } }
        end
        return nil
      end
    end)

    after_each(function()
      vim.fn.getcwd = original_getcwd
      vim.loop.fs_stat = original_fs_stat
      vim.fn.readfile = original_readfile
    end)

    it("should validate target is a provider reference", function()
      vim.fn.readfile = function(path)
        return {
          "VALID={{vault:secret/app#api_key}}",
          "INVALID=just_a_string",
          "ALSO_INVALID=env:API_KEY"  -- Missing braces
        }
      end

      -- Valid reference should work
      local value1, error1 = provider:resolve("VALID")
      assert.is_nil(error1)
      assert.equals("{{vault:secret/app#api_key}}", value1)

      -- Invalid references should return errors
      local value2, error2 = provider:resolve("INVALID")
      assert.is_nil(value2)
      assert.is_not_nil(error2)
      assert.is_true(string.find(error2, "must contain at least one provider reference") ~= nil)

      local value3, error3 = provider:resolve("ALSO_INVALID")
      assert.is_nil(value3)
      assert.is_not_nil(error3)
      assert.is_true(string.find(error3, "must contain at least one provider reference") ~= nil)
    end)
  end)

  describe("metadata", function()
    it("should provide refs-specific metadata", function()
      local metadata = provider:get_metadata()

      assert.is_boolean(metadata.refs_loaded)
      assert.is_number(metadata.refs_count)
      assert.is_table(metadata.cache_stats)
    end)
  end)
end)