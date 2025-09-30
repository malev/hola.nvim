# HashiCorp Vault Provider

This document covers the HashiCorp Vault provider in hola.nvim's provider system.

## Overview

The `vault` provider fetches secrets from HashiCorp Vault using the `{{vault:path#field}}` syntax. This provides enterprise-grade secret management for your HTTP requests.

> See [PROVIDERS.md](PROVIDERS.md) for an overview of the provider system and its security benefits.

## Quick Start

1. **Install and authenticate with Vault CLI**:
   ```bash
   # Install from https://www.vaultproject.io/
   vault auth -method=userpass username=your-username
   ```

2. **Use Vault secrets in your requests**:
   ```http
   GET https://api.example.com/secure
   Authorization: Bearer {{vault:secret/tokens#api_key}}
   ```

The Vault provider works automatically - no additional configuration needed in hola.nvim.

## Syntax

Vault variables use the format: `{{vault:path#field}}`

- **vault**: The provider name (always "vault")
- **path**: The secret path in Vault (e.g., "secret/api", "kv/prod/tokens")
- **field**: The field name within the secret (e.g., "api_key", "password")

### Examples

```http
### API Authentication
GET https://api.example.com/users
Authorization: Bearer {{vault:secret/api#token}}

### Database Connection
POST https://db.example.com/query
X-DB-User: {{vault:secret/database#username}}
X-DB-Pass: {{vault:secret/database#password}}
```

## Commands

hola.nvim provides several commands for managing Vault integration:

### `:HolaVaultStatus`
Check the current status of your Vault integration:
```
:HolaVaultStatus
```

Shows:
- Vault CLI availability and version
- Authentication status
- Connection to Vault server
- Any configuration issues

## Usage with Other Providers

The Vault provider works seamlessly with other providers:

```toml
# oauth.toml - Use Vault for OAuth credentials
[oauth.secure_service]
token_url = "https://auth.example.com/oauth/token"
client_id = "{{vault:secret/oauth#client_id}}"
client_secret = "{{vault:secret/oauth#client_secret}}"
```

```bash
# refs - Create shortcuts to complex Vault paths
API_TOKEN=vault:kv/data/prod/api#token
DB_PASSWORD=vault:kv/data/prod/database#password
```

```http
# HTTP requests - Mix providers as needed
GET https://api.example.com/secure
Authorization: Bearer {{refs:API_TOKEN}}
X-DB-Password: {{vault:secret/db#password}}
X-Service-Token: {{oauth:secure_service}}
```

## Security Features

- **Memory-Only Caching**: Secrets cached for 5 minutes, never written to disk
- **Automatic Cleanup**: Cache cleared when Neovim exits
- **CLI Integration**: Uses your existing Vault CLI authentication

## Troubleshooting

### Common Issues

#### 1. "Vault CLI not found"
**Problem**: The `vault` command is not available in your PATH.

**Solution**:
- Install the Vault CLI from [vaultproject.io](https://www.vaultproject.io/)
- Ensure it's in your PATH
- Restart Neovim after installation

#### 2. "Authentication required"
**Problem**: You're not authenticated with Vault.

**Solution**:
```bash
# Use your preferred auth method
vault auth -method=userpass username=your-username
vault auth -method=ldap username=your-username
vault auth -method=aws
```

#### 3. "Secret not found"
**Problem**: The specified secret path or field doesn't exist.

**Solutions**:
- Verify the secret exists: `vault kv get secret/path`
- Check your permissions: `vault token capabilities secret/path`
- Ensure correct path format (some Vault configurations use `kv/` prefix)

#### 4. "Connection refused"
**Problem**: Cannot connect to Vault server.

**Solutions**:
- Check VAULT_ADDR: `echo $VAULT_ADDR`
- Verify server is running and accessible
- Check network connectivity and firewalls

#### 5. "Permission denied"
**Problem**: Your token doesn't have permission to read the secret.

**Solutions**:
- Check token capabilities: `vault token capabilities secret/path`
- Request appropriate permissions from your Vault administrator
- Verify you're using the correct namespace (if using Vault Enterprise)

### Debug Information

To get detailed information about your Vault setup:

1. **Check Vault CLI status**:
   ```bash
   vault status
   vault token lookup
   ```

2. **Test secret access**:
   ```bash
   vault kv get secret/your/path
   ```

3. **Check hola.nvim vault status**:
   ```
   :HolaVaultStatus
   ```

4. **Enable detailed logging** (if needed):
   ```bash
   export VAULT_LOG_LEVEL=debug
   ```

## Support

If you encounter issues with Vault integration:

1. Check this troubleshooting guide
2. Run `:HolaVaultStatus` for diagnostic information
3. Verify your Vault CLI configuration
4. Check the [hola.nvim repository](https://github.com/malev/hola.nvim) for known issues

For Vault-specific issues, consult the [HashiCorp Vault documentation](https://www.vaultproject.io/docs).
