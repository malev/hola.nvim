local curl = require('plenary.curl')

local M = {}

-- Memory cache for OAuth tokens (session-scoped)
local oauth_cache = {}

-- Cache configuration
local CACHE_TTL_SECONDS = 300 -- 5 minutes buffer before expiration
local OAUTH_TIMEOUT_SECONDS = 10

--- Check if cached token is still valid
--- @param cached_token table Cached token data
--- @return boolean True if cache is valid
local function is_cache_valid(cached_token)
  if not cached_token then
    return false
  end

  -- Use the token's actual expiration time with buffer
  local buffer_time = CACHE_TTL_SECONDS
  return os.time() < (cached_token.expires_at - buffer_time)
end

--- Store token in cache
--- @param env_suffix string Environment suffix (default, staging, etc.)
--- @param token_data table Token response data
local function cache_token(env_suffix, token_data)
  local expires_at = os.time() + (token_data.expires_in or 3600)

  oauth_cache[env_suffix] = {
    access_token = token_data.access_token,
    token_type = token_data.token_type or 'Bearer',
    expires_at = expires_at,
    acquired_at = os.time(),
  }
end

--- Get token from cache
--- @param env_suffix string Environment suffix
--- @return string|nil Cached token or nil
local function get_cached_token(env_suffix)
  local cached = oauth_cache[env_suffix]
  if is_cache_valid(cached) then
    return cached.access_token
  else
    -- Clean up expired cache entry
    oauth_cache[env_suffix] = nil
    return nil
  end
end

--- Build Basic Auth header
--- @param client_id string OAuth client ID
--- @param client_secret string OAuth client secret
--- @return string Basic auth header value
local function build_basic_auth(client_id, client_secret)
  local credentials = client_id .. ':' .. client_secret
  local encoded = vim.fn.substitute(vim.fn.system('echo -n "' .. credentials .. '" | base64'), '\n', '', 'g')
  return 'Basic ' .. encoded
end

--- Make OAuth token request
--- @param config table OAuth configuration
--- @return table HTTP response
local function make_oauth_request(config)
  local headers = {}
  local body = ''

  if config.auth_method == 'basic_auth' then
    headers['Authorization'] = build_basic_auth(config.client_id, config.client_secret)
    headers['Content-Type'] = config.content_type or 'application/x-www-form-urlencoded'
    body = 'grant_type=' .. config.grant_type
    if config.scope then
      body = body .. '&scope=' .. config.scope
    end
  elseif config.auth_method == 'form_data' then
    headers['Content-Type'] = config.content_type or 'application/x-www-form-urlencoded'
    body = 'grant_type=' .. config.grant_type ..
           '&client_id=' .. config.client_id ..
           '&client_secret=' .. config.client_secret
    if config.scope then
      body = body .. '&scope=' .. config.scope
    end
  elseif config.auth_method == 'json_body' then
    headers['Content-Type'] = config.content_type or 'application/json'
    local request_data = {
      grant_type = config.grant_type,
      client_id = config.client_id,
      client_secret = config.client_secret
    }
    if config.scope then
      request_data.scope = config.scope
    end
    if config.audience then
      request_data.audience = config.audience
    end
    body = vim.fn.json_encode(request_data)
  else
    error('Unsupported OAuth auth method: ' .. (config.auth_method or 'nil'))
  end

  -- Add custom headers if specified
  if config.custom_headers then
    for header_pair in config.custom_headers:gmatch('[^,]+') do
      local key, value = header_pair:match('([^:]+):(.+)')
      if key and value then
        headers[vim.trim(key)] = vim.trim(value)
      end
    end
  end

  local response = curl.post(config.token_url, {
    headers = headers,
    body = body,
    timeout = OAUTH_TIMEOUT_SECONDS * 1000, -- convert to milliseconds
  })

  return response
end

--- Get OAuth configuration for environment
--- @param env_suffix string Environment suffix (default, staging, etc.)
--- @param env_sources table Array of environment variable sources to search
--- @return table OAuth configuration
local function get_oauth_config(env_suffix, env_sources)
  local suffix = env_suffix == 'default' and '' or '_' .. env_suffix:upper()

  -- Helper function to find value in multiple sources
  local function find_env_value(key)
    for _, source in ipairs(env_sources or {}) do
      if source and source[key] then
        return source[key]
      end
    end
    return nil
  end

  local config = {
    token_url = find_env_value('OAUTH_TOKEN_URL' .. suffix),
    client_id = find_env_value('OAUTH_CLIENT_ID' .. suffix),
    client_secret = find_env_value('OAUTH_CLIENT_SECRET' .. suffix),
    grant_type = find_env_value('OAUTH_GRANT_TYPE' .. suffix) or 'client_credentials',
    scope = find_env_value('OAUTH_SCOPE' .. suffix),
    auth_method = find_env_value('OAUTH_AUTH_METHOD' .. suffix) or 'basic_auth',
    content_type = find_env_value('OAUTH_CONTENT_TYPE' .. suffix),
    audience = find_env_value('OAUTH_AUDIENCE' .. suffix),
    custom_headers = find_env_value('OAUTH_CUSTOM_HEADERS' .. suffix),
  }

  if not config.token_url or not config.client_id or not config.client_secret then
    error('Missing OAuth configuration for environment: ' .. env_suffix)
  end

  return config
end

--- Get OAuth token for environment
--- @param env_suffix string|nil Environment suffix (defaults to 'default')
--- @param env_sources table|nil Array of environment variable sources to search
--- @return string|nil, string|nil access_token, error_message
function M.get_token(env_suffix, env_sources)
  env_suffix = env_suffix or 'default'
  env_sources = env_sources or {vim.env}

  -- Check cache first
  local cached_token = get_cached_token(env_suffix)
  if cached_token then
    return cached_token, nil
  end

  -- Get OAuth configuration
  local ok, config = pcall(get_oauth_config, env_suffix, env_sources)
  if not ok then
    return nil, config -- config contains the error message
  end

  -- Make OAuth request
  local response = make_oauth_request(config)

  if response.status ~= 200 then
    local error_msg = 'OAuth request failed with status ' .. response.status
    if response.body then
      local ok_parse, error_data = pcall(vim.fn.json_decode, response.body)
      if ok_parse and error_data.error then
        error_msg = error_msg .. ': ' .. error_data.error
        if error_data.error_description then
          error_msg = error_msg .. ' - ' .. error_data.error_description
        end
      end
    end
    return nil, error_msg
  end

  local ok_parse, token_data = pcall(vim.fn.json_decode, response.body)
  if not ok_parse or not token_data.access_token then
    return nil, 'Invalid OAuth response format'
  end

  -- Cache the token
  cache_token(env_suffix, token_data)

  return token_data.access_token, nil
end

--- Clear cached OAuth tokens
--- @param env_suffix string|nil Environment suffix (clears all if nil)
function M.clear_cache(env_suffix)
  if env_suffix then
    oauth_cache[env_suffix] = nil
  else
    oauth_cache = {}
  end
end

--- Get OAuth token status for all environments
--- @return table Status information for all cached tokens
function M.get_status()
  local status = {}

  for env, token_data in pairs(oauth_cache) do
    status[env] = {
      expires_at = token_data.expires_at,
      acquired_at = token_data.acquired_at,
      expired = not is_cache_valid(token_data),
      token_type = token_data.token_type or 'Bearer'
    }
  end

  return status
end

--- Get cache statistics (useful for debugging)
--- @return table Cache statistics
function M.get_cache_stats()
  local stats = {
    total_entries = 0,
    valid_entries = 0,
    expired_entries = 0,
  }

  for _, cached_token in pairs(oauth_cache) do
    stats.total_entries = stats.total_entries + 1
    if is_cache_valid(cached_token) then
      stats.valid_entries = stats.valid_entries + 1
    else
      stats.expired_entries = stats.expired_entries + 1
    end
  end

  return stats
end

return M