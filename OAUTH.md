# OAuth 2.0 Server-to-Server Authentication in hola.nvim

This guide covers OAuth 2.0 server-to-server authentication flows in hola.nvim, enabling seamless authentication with API gateways like AWS Cognito, Auth0, Apigee, and custom OAuth providers without browser interaction.

## Overview

OAuth 2.0 server-to-server authentication allows applications to authenticate directly with APIs without user intervention. This is perfect for:

- **API Gateway Integration**: AWS Cognito, Auth0, Apigee
- **Microservices Authentication**: Service-to-service communication

## Supported OAuth Flows

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

## Quick Start

### 1. Configure Your OAuth Service

Create an `oauth.toml` file:

```toml
[oauth.my_service]
token_url = "https://auth.example.com/oauth/token"
client_id = "your_client_id"
client_secret = "your_client_secret"
grant_type = "client_credentials"
scope = "read:users write:orders"
```

### 2. Use OAuth Tokens in HTTP Files

```http
### Create order with OAuth
POST https://api.example.com/v1/orders
Authorization: Bearer {{oauth:my_service}}
Content-Type: application/json

{
  "product_id": "12345",
  "quantity": 2
}
```

### 3. Send Requests

Use `:HolaSend` as usual. hola.nvim will:
1. Detect the `{{oauth:my_service}}` template
2. Load configuration from `oauth.toml`
3. Check for cached valid tokens
4. Automatically obtain new tokens if needed
5. Replace the template with the actual token
6. Execute the HTTP request

## Configuration

OAuth configuration is handled through the `oauth.toml` file using TOML format. Here are all supported options:

### Basic Configuration

```toml
[oauth.service_name]
# Required Settings
token_url = "https://auth.example.com/oauth/token"      # OAuth token endpoint
client_id = "your_client_id"                            # OAuth client ID
client_secret = "your_client_secret"                    # OAuth client secret

# Optional Settings
grant_type = "client_credentials"                       # Grant type (default: client_credentials)
scope = "read:users write:orders"                       # Requested scopes
auth_method = "basic_auth"                              # Authentication method
content_type = "application/x-www-form-urlencoded"      # Request content type
```

### Using Provider References

You can reference other providers (like Vault) for sensitive values:

```toml
[oauth.secure_service]
token_url = "https://auth.example.com/oauth/token"
client_id = "{{vault:secret/oauth#client_id}}"
client_secret = "{{vault:secret/oauth#client_secret}}"
scope = "{{API_SCOPE}}"  # from .env or OS environment
```

### Authentication Methods

Different OAuth providers expect different authentication formats:

#### `basic_auth` (Default)
Credentials sent via Authorization header:
```toml
[oauth.my_service]
auth_method = "basic_auth"
content_type = "application/x-www-form-urlencoded"
```

#### `form_data`
Credentials sent in POST body:
```toml
[oauth.my_service]
auth_method = "form_data"
content_type = "application/x-www-form-urlencoded"
```

#### `json_body`
Credentials sent as JSON in POST body:
```toml
[oauth.my_service]
auth_method = "json_body"
content_type = "application/json"
```

#### `header_bearer`
Credentials sent as Bearer token in Authorization header:
```toml
[oauth.my_service]
auth_method = "header_bearer"
```

### Advanced Configuration

```toml
[oauth.advanced_service]
# Custom Headers
custom_headers = "X-API-Version:2.0,X-Source:hola-nvim"

# Provider-specific parameters
audience = "https://your-api.com"      # Auth0 audience parameter
username = "service_account"           # ROPC flow username
password = "service_password"          # ROPC flow password
```

## OAuth Service Examples

### AWS Cognito

AWS Cognito uses Basic Auth with form-encoded body:

```toml
[oauth.aws_cognito]
token_url = "https://your-domain.auth.us-east-1.amazoncognito.com/oauth2/token"
client_id = "your_cognito_client_id"
client_secret = "your_cognito_client_secret"
grant_type = "client_credentials"
auth_method = "basic_auth"
content_type = "application/x-www-form-urlencoded"
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

```toml
[oauth.auth0]
token_url = "https://your-domain.auth0.com/oauth/token"
client_id = "your_auth0_client_id"
client_secret = "your_auth0_client_secret"
grant_type = "client_credentials"
auth_method = "json_body"
content_type = "application/json"
audience = "https://your-api.com"
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

```toml
[oauth.apigee]
token_url = "https://your-org-env.apigee.net/oauth/v2/accesstoken"
client_id = "your_apigee_client_id"
client_secret = "your_apigee_client_secret"
grant_type = "client_credentials"
auth_method = "form_data"
content_type = "application/x-www-form-urlencoded"
```

**HTTP Request Example:**
```http
POST https://your-org-env.apigee.net/oauth/v2/accesstoken
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=your_client_id&client_secret=your_secret
```

### Custom OAuth Provider

For custom OAuth providers, adjust the configuration as needed:

```toml
[oauth.custom_provider]
token_url = "https://custom-auth.example.com/token"
client_id = "custom_client_123"
client_secret = "custom_secret_456"
grant_type = "client_credentials"
auth_method = "basic_auth"
scope = "api:read api:write"
custom_headers = "X-Provider:custom,X-Version:v1"
```

## Token Management

### Automatic Token Handling

hola.nvim handles OAuth tokens automatically:

1. **Token Detection**: When `{{oauth:service}}` is found in a request
2. **Configuration Loading**: Loads service configuration from `oauth.toml`
3. **Cache Check**: Checks if a valid cached token exists for the service
4. **Token Acquisition**: Fetches new token if needed using service OAuth config
5. **Token Injection**: Replaces template with actual token
6. **Request Execution**: Executes the HTTP request with the token

### Smart Token Refresh

- **Automatic Refresh**: Tokens are refreshed 5 minutes before expiration
- **Failure Recovery**: Invalid tokens are automatically cleared and re-acquired
- **Memory Caching**: Current tokens are kept in memory for performance
- **Secure Storage**: Cache files use restrictive permissions (600)

## Multi-Environment Support

Configure different environments by defining multiple services in your `oauth.toml`:

### Environment Configuration

```toml
# Production
[oauth.prod]
token_url = "https://auth.example.com/oauth/token"
client_id = "prod_client_id"
client_secret = "prod_client_secret"

# Staging
[oauth.staging]
token_url = "https://staging-auth.example.com/oauth/token"
client_id = "staging_client_id"
client_secret = "staging_client_secret"

# Development
[oauth.dev]
token_url = "https://dev-auth.example.com/oauth/token"
client_id = "dev_client_id"
client_secret = "dev_client_secret"
```

### Environment Usage

```http
### Production API call
GET https://api.example.com/v1/users
Authorization: Bearer {{oauth:prod}}

### Staging API call
GET https://staging-api.example.com/v1/users
Authorization: Bearer {{oauth:staging}}

### Development API call
GET https://dev-api.example.com/v1/users
Authorization: Bearer {{oauth:dev}}
```
