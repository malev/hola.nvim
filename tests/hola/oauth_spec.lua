local oauth = require("hola.oauth")

describe("hola oauth module", function()
	-- Clear cache before each test
	before_each(function()
		oauth.clear_cache()
	end)

	describe("get_token", function()
		it("should return error when OAuth configuration is missing", function()
			local empty_sources = { {} }

			local token, error = oauth.get_token("default", empty_sources)

			assert.is_nil(token)
			assert.matches("Missing OAuth configuration", error)
		end)

		it("should return error when OAuth request fails with 401", function()
			-- Mock curl response
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 401,
					body = '{"error": "invalid_client", "error_description": "Invalid credentials"}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(token)
			assert.matches("OAuth request failed with status 401", error)
			assert.matches("invalid_client", error)

			-- Restore original function
			curl.post = original_post
		end)

		it("should return error when OAuth response is invalid JSON", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = "invalid json",
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(token)
			assert.matches("Invalid OAuth response format", error)

			curl.post = original_post
		end)

		it("should return error when OAuth response lacks access_token", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = '{"token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(token)
			assert.matches("Invalid OAuth response format", error)

			curl.post = original_post
		end)

		it("should successfully fetch and cache OAuth token with basic_auth", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			local captured_request = nil

			curl.post = function(url, options)
				captured_request = { url = url, options = options }
				return {
					status = 200,
					body = '{"access_token": "test_token_123", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/oauth/token",
					OAUTH_CLIENT_ID = "test_client_id",
					OAUTH_CLIENT_SECRET = "test_client_secret",
					OAUTH_GRANT_TYPE = "client_credentials",
					OAUTH_SCOPE = "read:users",
					OAUTH_AUTH_METHOD = "basic_auth",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(error)
			assert.equals("test_token_123", token)

			-- Verify request was made correctly
			assert.equals("http://test.com/oauth/token", captured_request.url)
			assert.equals("application/x-www-form-urlencoded", captured_request.options.headers["Content-Type"])
			assert.matches("Basic ", captured_request.options.headers["Authorization"])
			assert.equals("grant_type=client_credentials&scope=read:users", captured_request.options.body)

			curl.post = original_post
		end)

		it("should successfully fetch OAuth token with form_data method", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			local captured_request = nil

			curl.post = function(url, options)
				captured_request = { url = url, options = options }
				return {
					status = 200,
					body = '{"access_token": "apigee_token_456", "token_type": "Bearer", "expires_in": 1800}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://apigee.com/oauth/v2/accesstoken",
					OAUTH_CLIENT_ID = "apigee_client",
					OAUTH_CLIENT_SECRET = "apigee_secret",
					OAUTH_AUTH_METHOD = "form_data",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(error)
			assert.equals("apigee_token_456", token)

			-- Verify form_data method
			assert.is_nil(captured_request.options.headers["Authorization"])
			assert.matches("grant_type=client_credentials", captured_request.options.body)
			assert.matches("client_id=apigee_client", captured_request.options.body)
			assert.matches("client_secret=apigee_secret", captured_request.options.body)

			curl.post = original_post
		end)

		it("should successfully fetch OAuth token with json_body method", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			local captured_request = nil

			curl.post = function(url, options)
				captured_request = { url = url, options = options }
				return {
					status = 200,
					body = '{"access_token": "auth0_token_789", "token_type": "Bearer", "expires_in": 86400}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://auth0.com/oauth/token",
					OAUTH_CLIENT_ID = "auth0_client",
					OAUTH_CLIENT_SECRET = "auth0_secret",
					OAUTH_AUTH_METHOD = "json_body",
					OAUTH_AUDIENCE = "https://api.example.com",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(error)
			assert.equals("auth0_token_789", token)

			-- Verify JSON body method
			assert.equals("application/json", captured_request.options.headers["Content-Type"])
			local body_data = vim.fn.json_decode(captured_request.options.body)
			assert.equals("client_credentials", body_data.grant_type)
			assert.equals("auth0_client", body_data.client_id)
			assert.equals("auth0_secret", body_data.client_secret)
			assert.equals("https://api.example.com", body_data.audience)

			curl.post = original_post
		end)

		it("should handle multi-environment configurations", function()
			local curl = require("plenary.curl")
			local original_post = curl.post

			curl.post = function()
				return {
					status = 200,
					body = '{"access_token": "staging_token_999", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					-- Staging environment configuration
					OAUTH_TOKEN_URL_STAGING = "http://staging-auth.com/token",
					OAUTH_CLIENT_ID_STAGING = "staging_client",
					OAUTH_CLIENT_SECRET_STAGING = "staging_secret",
				},
			}

			local token, error = oauth.get_token("staging", env_sources)

			assert.is_nil(error)
			assert.equals("staging_token_999", token)

			curl.post = original_post
		end)

		it("should return cached token without making request", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			local request_count = 0

			curl.post = function()
				request_count = request_count + 1
				return {
					status = 200,
					body = '{"access_token": "cached_token_111", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			-- First request should make HTTP call
			local token1, error1 = oauth.get_token("default", env_sources)
			assert.is_nil(error1)
			assert.equals("cached_token_111", token1)
			assert.equals(1, request_count)

			-- Second request should use cache
			local token2, error2 = oauth.get_token("default", env_sources)
			assert.is_nil(error2)
			assert.equals("cached_token_111", token2)
			assert.equals(1, request_count) -- Should not have made another request

			curl.post = original_post
		end)

		it("should handle custom headers configuration", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			local captured_request = nil

			curl.post = function(url, options)
				captured_request = { url = url, options = options }
				return {
					status = 200,
					body = '{"access_token": "custom_token_222", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
					OAUTH_CUSTOM_HEADERS = "X-API-Version:2.0,X-Source:hola-nvim",
				},
			}

			local token, error = oauth.get_token("default", env_sources)

			assert.is_nil(error)
			assert.equals("custom_token_222", token)
			assert.equals("2.0", captured_request.options.headers["X-API-Version"])
			assert.equals("hola-nvim", captured_request.options.headers["X-Source"])

			curl.post = original_post
		end)
	end)

	describe("clear_cache", function()
		it("should clear specific environment cache", function()
			-- Setup mock and get tokens for different environments
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = '{"access_token": "test_token", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
					OAUTH_TOKEN_URL_STAGING = "http://staging.com/token",
					OAUTH_CLIENT_ID_STAGING = "staging_id",
					OAUTH_CLIENT_SECRET_STAGING = "staging_secret",
				},
			}

			-- Get tokens for both environments
			oauth.get_token("default", env_sources)
			oauth.get_token("staging", env_sources)

			-- Verify both are in status
			local status = oauth.get_status()
			assert.is_not_nil(status.default)
			assert.is_not_nil(status.staging)

			-- Clear only staging
			oauth.clear_cache("staging")

			-- Verify only staging was cleared
			local status_after = oauth.get_status()
			assert.is_not_nil(status_after.default)
			assert.is_nil(status_after.staging)

			curl.post = original_post
		end)

		it("should clear all cache when no environment specified", function()
			-- Similar setup as above but clear all
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = '{"access_token": "test_token", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			oauth.get_token("default", env_sources)

			local status_before = oauth.get_status()
			assert.is_not_nil(status_before.default)

			oauth.clear_cache() -- Clear all

			local status_after = oauth.get_status()
			assert.equals(0, vim.tbl_count(status_after))

			curl.post = original_post
		end)
	end)

	describe("get_status", function()
		it("should return empty status when no tokens cached", function()
			local status = oauth.get_status()
			assert.equals(0, vim.tbl_count(status))
		end)

		it("should return status information for cached tokens", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = '{"access_token": "status_token", "token_type": "Bearer", "expires_in": 1800}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			oauth.get_token("default", env_sources)

			local status = oauth.get_status()
			assert.is_not_nil(status.default)
			assert.equals("Bearer", status.default.token_type)
			assert.is_number(status.default.expires_at)
			assert.is_number(status.default.acquired_at)
			assert.is_boolean(status.default.expired)

			curl.post = original_post
		end)
	end)

	describe("get_cache_stats", function()
		it("should return correct cache statistics", function()
			local curl = require("plenary.curl")
			local original_post = curl.post
			curl.post = function()
				return {
					status = 200,
					body = '{"access_token": "stats_token", "token_type": "Bearer", "expires_in": 3600}',
				}
			end

			local env_sources = {
				{
					OAUTH_TOKEN_URL = "http://test.com/token",
					OAUTH_CLIENT_ID = "test_id",
					OAUTH_CLIENT_SECRET = "test_secret",
				},
			}

			-- Get a token to populate cache
			oauth.get_token("default", env_sources)

			local stats = oauth.get_cache_stats()
			assert.equals(1, stats.total_entries)
			assert.equals(1, stats.valid_entries)
			assert.equals(0, stats.expired_entries)

			curl.post = original_post
		end)
	end)
end)
