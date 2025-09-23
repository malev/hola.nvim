# HashiCorp Vault Integration

This document provides comprehensive information about using HashiCorp Vault with hola.nvim for enterprise-grade secret management.

## Overview

hola.nvim integrates with HashiCorp Vault to provide secure secret management for your HTTP requests. Instead of storing sensitive information in `.env` files or environment variables, you can fetch secrets directly from Vault using a simple syntax.

## Quick Start

1. **Install Vault CLI**: Download and install the HashiCorp Vault CLI from [vaultproject.io](https://www.vaultproject.io/)

2. **Authenticate with Vault**: Configure your Vault authentication
   ```bash
   vault auth -method=userpass username=your-username
   # or use other auth methods like LDAP, AWS, etc.
   ```

3. **Enable Vault in hola.nvim**:
   ```lua
   require("hola").setup({
     vault = { enabled = true }
   })
   ```

4. **Use Vault secrets in your requests**:
   ```http
   GET https://api.example.com/secure
   Authorization: Bearer {{vault:secret/tokens#api_key}}
   ```

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

### Mixed Variables
POST https://{{BASE_URL}}/api
Authorization: Bearer {{vault:secret/tokens#api_key}}
Content-Type: application/json

{
  "environment": "{{ENVIRONMENT}}",
  "secret_key": "{{vault:secret/app#secret_key}}"
}
```

## Commands

hola.nvim provides several commands for managing Vault integration:

### `:HolaVaultStatus`
Check the current status of your Vault integration:
```
:HolaVaultStatus
```

This command shows:
- Vault CLI availability and version
- Authentication status
- Connection to Vault server
- Any configuration issues

### `:HolaEnableVault`
Enable Vault integration for the current session:
```
:HolaEnableVault
```

### `:HolaDisableVault`
Disable Vault integration for the current session:
```
:HolaDisableVault
```

## Configuration

```lua
require("hola").setup({
  vault = {
    enabled = true,  -- Enable/disable vault integration
  }
})
```

## Security Features

### Memory-Only Caching
- Secrets are cached in memory for 5 minutes to improve performance
- No secrets are written to disk
- Cache is cleared when Neovim exits

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
