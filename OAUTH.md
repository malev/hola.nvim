# OAuth 2.0 Server-to-Server Authentication in hola.nvim

This guide covers OAuth 2.0 server-to-server authentication flows in hola.nvim, enabling seamless authentication with API gateways like AWS Cognito, Auth0, Apigee, and custom OAuth providers without browser interaction.

## Table of Contents

- [Overview](#overview)
- [Supported OAuth Flows](#supported-oauth-flows)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Provider Examples](#provider-examples)
- [Usage in HTTP Files](#usage-in-http-files)
- [Token Management](#token-management)
- [Multi-Environment Support](#multi-environment-support)
- [Commands](#commands)
- [Troubleshooting](#troubleshooting)

## Overview

OAuth 2.0 server-to-server authentication allows applications to authenticate directly with APIs without user intervention. This is perfect for:

- **API Gateway Integration**: AWS Cognito, Auth0, Apigee
- **Microservices Authentication**: Service-to-service communication
- **Enterprise APIs**: Corporate authentication systems
- **Headless Environments**: CI/CD pipelines, server deployments

## Supported OAuth Flows

### Client Credentials Flow (Primary)

The most common server-to-server flow where the client acts on its own behalf.

```
Client → OAuth Server: POST /oauth/token
                      grant_type=client_credentials
                      client_id=xxx
                      client_secret=yyy

OAuth Server → Client: {
                        "access_token": "...",
                        "token_type": "Bearer",
                        "expires_in": 3600
                      }
```

### Resource Owner Password Credentials (ROPC)

Used when the client has user credentials and can authenticate directly (less common).

## Quick Start

### 1. Configure Your Provider

Create or update your `.env` file:

```bash
# Basic OAuth Configuration
OAUTH_TOKEN_URL=https://auth.example.com/oauth/token
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
OAUTH_GRANT_TYPE=client_credentials
OAUTH_SCOPE=read:users write:orders
```

### 2. Use OAuth Tokens in HTTP Files

```http
### Get user data with OAuth
GET https://api.example.com/v1/users
Authorization: Bearer {{OAUTH_TOKEN}}
Content-Type: application/json

###

### Create order with OAuth
POST https://api.example.com/v1/orders
Authorization: Bearer {{OAUTH_TOKEN}}
Content-Type: application/json

{
  "product_id": "12345",
  "quantity": 2
}
```

### 3. Send Requests

Use `:HolaSend` as usual. hola.nvim will:
1. Detect the `{{OAUTH_TOKEN}}` template
2. Check for cached valid tokens
3. Automatically obtain new tokens if needed
4. Replace the template with the actual token
5. Execute the HTTP request

## Configuration

OAuth configuration is handled through environment variables in `.env` files. Here are all supported options:

### Basic Configuration

```bash
# Required Settings
OAUTH_TOKEN_URL=https://auth.example.com/oauth/token    # OAuth token endpoint
OAUTH_CLIENT_ID=your_client_id                          # OAuth client ID
OAUTH_CLIENT_SECRET=your_client_secret                  # OAuth client secret

# Optional Settings
OAUTH_GRANT_TYPE=client_credentials                     # Grant type (default: client_credentials)
OAUTH_SCOPE=read:users write:orders                    # Requested scopes
OAUTH_AUTH_METHOD=basic_auth                           # Authentication method
OAUTH_CONTENT_TYPE=application/x-www-form-urlencoded   # Request content type
```

### Authentication Methods

Different OAuth providers expect different authentication formats:

#### `basic_auth` (Default)
Credentials sent via Authorization header:
```bash
OAUTH_AUTH_METHOD=basic_auth
OAUTH_CONTENT_TYPE=application/x-www-form-urlencoded
```

#### `form_data`
Credentials sent in POST body:
```bash
OAUTH_AUTH_METHOD=form_data
OAUTH_CONTENT_TYPE=application/x-www-form-urlencoded
```

#### `json_body`
Credentials sent as JSON in POST body:
```bash
OAUTH_AUTH_METHOD=json_body
OAUTH_CONTENT_TYPE=application/json
```

#### `header_bearer`
Credentials sent as Bearer token in Authorization header:
```bash
OAUTH_AUTH_METHOD=header_bearer
```

### Advanced Configuration

```bash
# Custom Headers
OAUTH_CUSTOM_HEADERS=X-API-Version:2.0,X-Source:hola-nvim

# Provider-specific parameters
OAUTH_AUDIENCE=https://your-api.com                    # Auth0 audience parameter
OAUTH_USERNAME=service_account                         # ROPC flow username
OAUTH_PASSWORD=service_password                        # ROPC flow password
```

## Provider Examples

### AWS Cognito

AWS Cognito uses Basic Auth with form-encoded body:

```bash
# .env for AWS Cognito
OAUTH_TOKEN_URL=https://your-domain.auth.us-east-1.amazoncognito.com/oauth2/token
OAUTH_CLIENT_ID=your_cognito_client_id
OAUTH_CLIENT_SECRET=your_cognito_client_secret
OAUTH_GRANT_TYPE=client_credentials
OAUTH_AUTH_METHOD=basic_auth
OAUTH_CONTENT_TYPE=application/x-www-form-urlencoded
```

**HTTP Request Example:**
```http
POST https://your-domain.auth.us-east-1.amazoncognito.com/oauth2/token
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=your/scope
```

### Auth0

Auth0 uses JSON body with client credentials:

```bash
# .env for Auth0
OAUTH_TOKEN_URL=https://your-domain.auth0.com/oauth/token
OAUTH_CLIENT_ID=your_auth0_client_id
OAUTH_CLIENT_SECRET=your_auth0_client_secret
OAUTH_GRANT_TYPE=client_credentials
OAUTH_AUTH_METHOD=json_body
OAUTH_CONTENT_TYPE=application/json
OAUTH_AUDIENCE=https://your-api.com
```

**HTTP Request Example:**
```http
POST https://your-domain.auth0.com/oauth/token
Content-Type: application/json

{
  "grant_type": "client_credentials",
  "client_id": "your_auth0_client_id",
  "client_secret": "your_auth0_client_secret",
  "audience": "https://your-api.com"
}
```

### Apigee

Apigee uses form data in the request body:

```bash
# .env for Apigee
OAUTH_TOKEN_URL=https://your-org-env.apigee.net/oauth/v2/accesstoken
OAUTH_CLIENT_ID=your_apigee_client_id
OAUTH_CLIENT_SECRET=your_apigee_client_secret
OAUTH_GRANT_TYPE=client_credentials
OAUTH_AUTH_METHOD=form_data
OAUTH_CONTENT_TYPE=application/x-www-form-urlencoded
```

**HTTP Request Example:**
```http
POST https://your-org-env.apigee.net/oauth/v2/accesstoken
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=your_client_id&client_secret=your_secret
```

### Custom OAuth Provider

For custom OAuth providers, adjust the configuration as needed:

```bash
# .env for Custom Provider
OAUTH_TOKEN_URL=https://custom-auth.example.com/token
OAUTH_CLIENT_ID=custom_client_123
OAUTH_CLIENT_SECRET=custom_secret_456
OAUTH_GRANT_TYPE=client_credentials
OAUTH_AUTH_METHOD=basic_auth
OAUTH_SCOPE=api:read api:write
OAUTH_CUSTOM_HEADERS=X-Provider:custom,X-Version:v1
```

## Usage in HTTP Files

### Basic Usage

Use `{{OAUTH_TOKEN}}` anywhere in your HTTP files:

```http
### Get user profile
GET https://api.example.com/v1/user/profile
Authorization: Bearer {{OAUTH_TOKEN}}
Content-Type: application/json

###

### Update user settings
PUT https://api.example.com/v1/user/settings
Authorization: Bearer {{OAUTH_TOKEN}}
Content-Type: application/json

{
  "theme": "dark",
  "notifications": true
}
```

### Headers and Body

OAuth tokens can be used in any part of the request:

```http
### Custom authorization header
GET https://api.example.com/data
X-Auth-Token: {{OAUTH_TOKEN}}

###

### Token in request body
POST https://api.example.com/graphql
Content-Type: application/json

{
  "query": "{ user { name } }",
  "variables": {},
  "extensions": {
    "authorization": "{{OAUTH_TOKEN}}"
  }
}
```

## Token Management

### Automatic Token Handling

hola.nvim handles OAuth tokens automatically:

1. **Token Detection**: When `{{OAUTH_TOKEN*}}` is found in a request
2. **Cache Check**: Checks if a valid cached token exists
3. **Token Acquisition**: Fetches new token if needed using OAuth config
4. **Token Injection**: Replaces template with actual token
5. **Request Execution**: Executes the HTTP request with the token

### Token Caching

Tokens are cached securely on disk:

**Cache Location**: `~/.local/share/nvim/hola/oauth_cache.json`

**Cache Structure**:
```json
{
  "default": {
    "access_token": "eyJhbGciOiJSUzI1NiIs...",
    "token_type": "Bearer",
    "expires_at": 1234567890,
    "acquired_at": 1234564290
  },
  "staging": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_at": 1234567890
  }
}
```

### Smart Token Refresh

- **Automatic Refresh**: Tokens are refreshed 5 minutes before expiration
- **Failure Recovery**: Invalid tokens are automatically cleared and re-acquired
- **Memory Caching**: Current tokens are kept in memory for performance
- **Secure Storage**: Cache files use restrictive permissions (600)

## Multi-Environment Support

Configure different environments by adding suffixes to environment variables:

### Environment Configuration

```bash
# Production (default)
OAUTH_TOKEN_URL=https://auth.example.com/oauth/token
OAUTH_CLIENT_ID=prod_client_id
OAUTH_CLIENT_SECRET=prod_client_secret

# Staging
OAUTH_TOKEN_URL_STAGING=https://staging-auth.example.com/oauth/token
OAUTH_CLIENT_ID_STAGING=staging_client_id
OAUTH_CLIENT_SECRET_STAGING=staging_client_secret

# Development
OAUTH_TOKEN_URL_DEV=https://dev-auth.example.com/oauth/token
OAUTH_CLIENT_ID_DEV=dev_client_id
OAUTH_CLIENT_SECRET_DEV=dev_client_secret
```

### Environment Usage

```http
### Production API call
GET https://api.example.com/v1/users
Authorization: Bearer {{OAUTH_TOKEN}}

### Staging API call
GET https://staging-api.example.com/v1/users
Authorization: Bearer {{OAUTH_TOKEN_STAGING}}

### Development API call
GET https://dev-api.example.com/v1/users
Authorization: Bearer {{OAUTH_TOKEN_DEV}}
```

## Commands

hola.nvim provides several commands for managing OAuth tokens:

### `:HolaOAuthStatus`

Show current OAuth token status for all environments:

```
OAuth Token Status:
  default: Valid (expires in 2h 15m)
  staging: Valid (expires in 45m)
  dev: Expired (refresh needed)
```

### `:HolaOAuthRefresh [environment]`

Manually refresh OAuth tokens:

```vim
:HolaOAuthRefresh          " Refresh all environments
:HolaOAuthRefresh staging  " Refresh only staging environment
```

### `:HolaOAuthClear [environment]`

Clear cached OAuth tokens to force re-authentication:

```vim
:HolaOAuthClear           " Clear all cached tokens
:HolaOAuthClear staging   " Clear only staging tokens
```

### `:HolaOAuthConfig [environment]`

Interactive OAuth configuration setup (future feature):

```
Enter OAuth Token URL: https://auth.example.com/oauth/token
Enter Client ID: your_client_id
Enter Client Secret: [hidden input]
Select Grant Type:
  1. client_credentials (recommended)
  2. password
Select Auth Method:
  1. basic_auth (Authorization header)
  2. form_data (POST body form)
  3. json_body (POST body JSON)
Enter Scope (optional): read:users write:orders
Environment suffix (optional, e.g., _STAGING):

Configuration saved to .env file.
```

## Troubleshooting

### Common Issues

#### "Missing OAuth configuration"
```
Error: Missing OAuth configuration for environment: default
```

**Solution**: Ensure your `.env` file contains the required OAuth variables:
```bash
OAUTH_TOKEN_URL=https://auth.example.com/oauth/token
OAUTH_CLIENT_ID=your_client_id
OAUTH_CLIENT_SECRET=your_client_secret
```

#### "OAuth request failed with status 401"
```
Error: OAuth request failed with status 401: invalid_client
```

**Solutions**:
- Verify client ID and secret are correct
- Check that the OAuth endpoint URL is correct
- Ensure the authentication method matches your provider's requirements

#### "Invalid OAuth response format"
```
Error: Invalid OAuth response format
```

**Solutions**:
- Verify the OAuth endpoint returns valid JSON
- Check that the endpoint returns an `access_token` field
- Ensure the Content-Type is correctly set for your provider

### Environment Variable Issues

#### Variables not being loaded
1. Ensure `.env` file is in your current working directory
2. Check that variable names are spelled correctly
3. Verify there are no spaces around the `=` sign in `.env` file

#### Wrong environment being used
1. Check the suffix in your template variable (`{{OAUTH_TOKEN_STAGING}}`)
2. Ensure corresponding environment variables exist (`OAUTH_*_STAGING`)
3. Verify variable names match exactly (case-sensitive)

### Token Cache Issues

#### Tokens not being cached
1. Check that the cache directory exists: `~/.local/share/nvim/hola/`
2. Verify file permissions allow writing
3. Check for disk space issues

#### Stale tokens not refreshing
1. Use `:HolaOAuthClear` to force token refresh
2. Check system clock for time synchronization issues
3. Verify the OAuth response includes `expires_in` field

### Provider-Specific Issues

#### AWS Cognito
- Ensure the domain format is correct: `your-domain.auth.region.amazoncognito.com`
- Verify the client is configured for "Client credentials" grant type
- Check that required scopes are configured in Cognito

#### Auth0
- Ensure the `audience` parameter matches your API identifier
- Verify the application type is set to "Machine to Machine"
- Check that the client has been granted the required scopes

#### Apigee
- Verify the organization and environment in the URL
- Ensure the OAuth policy is properly configured in Apigee
- Check that the client credentials are correctly registered

### Debug Mode

Enable detailed logging for troubleshooting:

```lua
require("hola").setup({
  oauth = {
    debug = true  -- Enable OAuth debug logging
  }
})
```

This will log OAuth requests and responses to help identify issues.

## Security Considerations

### Credential Storage
- Never commit client secrets to version control
- Use environment variables or encrypted storage for secrets
- Consider using HashiCorp Vault for enterprise secret management

### Token Security
- Cache files use restrictive permissions (600)
- Tokens are automatically cleared on authentication failures
- Consider token rotation policies for production environments

### Network Security
- Always use HTTPS for OAuth endpoints
- Validate SSL certificates in production
- Consider network-level restrictions for sensitive environments

## Integration with Existing Features

OAuth 2.0 authentication integrates seamlessly with hola.nvim's existing features:

### Variable Resolution Priority
When processing templates, hola.nvim checks sources in this order:

1. **OAuth Tokens**: `{{OAUTH_TOKEN*}}` patterns
2. **HashiCorp Vault**: `{{vault:secret/path#field}}`
3. **Environment Variables**: `{{VARIABLE_NAME}}`
4. **`.env` Files**: Variables from `.env` file

### Mixed Authentication
You can combine OAuth with other authentication methods:

```http
### OAuth + API Key
GET https://api.example.com/analytics
Authorization: Bearer {{OAUTH_TOKEN}}
X-Analytics-Key: {{ANALYTICS_API_KEY}}

### OAuth + Vault Secrets
POST https://api.example.com/secure
Authorization: Bearer {{OAUTH_TOKEN}}
X-Database-Password: {{vault:secret/db#password}}
```

This comprehensive OAuth integration makes hola.nvim a powerful tool for modern API development and testing workflows.