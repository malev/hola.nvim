# Providers in hola.nvim

## Definition

A **provider** is a pluggable system that resolves template variables using the pattern `{{provider:identifier}}` by fetching values from external sources or services. Each provider handles its own authentication, caching, configuration, and data retrieval logic.

## Why Providers?

### Security: Flexible Secret Management Options

Providers offer different security levels depending on your needs:

**Environment Variables (`env` provider)**:
- **Use case**: Local development and non-sensitive configuration
- **Considerations**: Visible to processes, can appear in logs, risk of accidental commits
- **Best for**: Development environments, timeouts, URLs, debug flags

**External Secret Providers (`vault`, `oauth`)**:
- **Use case**: Production secrets and sensitive authentication
- **Benefits**: External secret storage, dynamic retrieval, automatic rotation
- **Best for**: API keys, tokens, passwords, certificates

This tiered approach lets you use simple environment variables for development while securing production credentials in dedicated secret management systems.

### Simplicity: Complex Operations Made Simple

Modern API development involves complex authentication flows that providers simplify:

**Without Providers (Manual OAuth)**:
```bash
# Terminal 1: Get OAuth token
curl -X POST https://auth.example.com/oauth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=abc&client_secret=xyz"

# Copy token from response, paste into into the request you'll be sending
# Repeat every hour when token expires
```

**With OAuth Provider**:
```http
GET https://api.example.com/users
Authorization: Bearer {{oauth:my_service}}
```

## Current Providers

### `env` Provider
- **Syntax**: `{{env:VARIABLE}}`
- **Purpose**: Retrieves variables from the environment or from dotenv files
- **Configuration**: Simple and fast local configuration

### `vault` Provider
- **Syntax**: `{{vault:secret/path#field}}`
- **Purpose**: Retrieves secrets from HashiCorp Vault
- **Authentication**: Uses vault tokens or other vault auth methods
- **Configuration**: Via vault CLI or environment variables

### `oauth` Provider
- **Syntax**: `{{oauth:service_name}}`
- **Purpose**: Provides OAuth 2.0 access tokens for service-to-service authentication
- **Authentication**: Client credentials flow with configurable auth methods
- **Configuration**: `oauth.toml` file with service definitions
- **Caching**: Automatic token refresh before expiration

### `refs` Provider
- **Syntax**: `{{refs:VARIABLE_NAME}}`
- **Purpose**: Creates aliases and shortcuts to other provider references
- **Configuration**: `refs` file with variable mappings
- **Special Capability**: Can reference other providers, creating a layer of indirection

