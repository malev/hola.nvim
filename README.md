# Hola.nvim: Your In-Neovim REST Command Center

> Send HTTP requests without leaving the comfort of your editor, with built-in environment and dotenv support!

## Installation: Get Ready to Say "¡Hola!" 👋

Just add this to your `plugins` table in your Neovim configuration (using your preferred plugin manager):

```lua
{
  "malev/hola.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("hola").setup({
      -- Optional configuration
      json = {
        auto_format = true,     -- Auto-format JSON responses
        enable_folding = true,  -- Enable JSON folding in buffer
      },
    })
  end,
}
```

*Commands:*

  * `:HolaSend`: Unleash the request! 🚀
  * `:HolaToggle`: Toggle between response body and metadata view
  * `:HolaClose`: Close response window
  * `:HolaFormatJson`: Toggle JSON formatting (formatted ↔ raw) ✨

## Example: Let's Send Some Requests! 📬

```http
### Get a list of awesome posts! ✨
GET https://jsonplaceholder.typicode.com/posts

### Create a brand new post (let\'s see if they like it!) ✍️
POST https://jsonplaceholder.typicode.com/posts

{"title": "hello from hola.nvim!"}

### Oops, let\'s pretend to delete post #1 🗑️
DELETE https://jsonplaceholder.typicode.com/posts/1
```

## Usage: Sending Your First "¡Hola!" 🎬

1.  **Open your `.http` request file:** Just like the cool example above.
2.  **Navigate to the request:** Place your cursor anywhere within the request block you want to send.
3.  **Say the magic words:** Execute the `:HolaSend` command.

... and BAM! 🎉 The response will appear in a sleek panel on the right.

**Need to dive deeper?**

* `:HolaToggle`: Switch between response body and metadata/headers view
* `:HolaClose`: Close the response window when you're done
* `:HolaFormatJson`: Toggle between beautifully formatted and raw JSON (JSON responses only)

## Recommended Keymaps: Supercharge Your Workflow! ⚡

Here are some handy keymaps to make sending requests a breeze. Add these to your Neovim configuration:

```lua
local map = vim.keymap.set

-- Hola keymaps - Send it! 🚀
map("n", "<leader>hs", "<cmd>:HolaSend<cr>", { desc = "Send request" })
-- Hola keymaps - Response navigation 👀
map({ "n", "v" }, "<leader>ht", "<cmd>:HolaToggle<cr>", { desc = "Toggle response body/metadata" })
map({ "n", "v" }, "<leader>hc", "<cmd>:HolaClose<cr>", { desc = "Close response window" })
-- Hola keymaps - JSON tools ✨
map({ "n", "v" }, "<leader>hf", "<cmd>:HolaFormatJson<cr>", { desc = "Toggle JSON formatting" })
```

## Beautiful JSON Responses with Smart Formatting! ✨

`hola.nvim` automatically detects JSON responses and provides powerful formatting and syntax highlighting features to make working with JSON a breeze.

### ✅ **Auto-Formatting**

JSON responses are automatically formatted with:
- **Smart indentation** (2 spaces by default)
- **Sorted keys** for consistent output
- **Compact arrays** for simple values: `[1, 2, 3, 4]`
- **Expanded arrays** for complex structures:
  ```json
  [
    {
      "name": "John"
    },
    {
      "name": "Jane"
    }
  ]
  ```

### 🎛️ **Interactive JSON Tools**

- **`:HolaFormatJson`** - Toggle between formatted and raw JSON views
- **Enhanced syntax highlighting** with proper JSON filetype detection
- **JSON folding support** for navigating large responses

### ⚙️ **Configuration**

Customize JSON behavior in your Neovim config:

```lua
require("hola").setup({
  json = {
    auto_format = true,        -- Auto-format JSON responses
    enable_folding = true,     -- Enable JSON folding in buffer
  },
})
```

## Configuration Management 🔧

`hola.nvim` provides flexible configuration management through environment variables and **providers** - powerful systems that fetch secrets and configuration from external sources.

### Environment Variables & .env Files

Use traditional `.env` files for local development and non-sensitive configuration:

```bash
# .env
API_URL=https://api.example.com
DEBUG=true
TIMEOUT=30
```

```http
GET {{API_URL}}/users?debug={{DEBUG}}
```

### Providers: Secure External Configuration

**Providers** use the pattern `{{provider:identifier}}` to fetch values from external systems:

- **`{{vault:secret/path#field}}`** - HashiCorp Vault secrets ([VAULT.md](VAULT.md))
- **`{{oauth:service}}`** - OAuth 2.0 access tokens ([OAUTH.md](OAUTH.md))
- **`{{refs:VARIABLE}}`** - Reference aliases to other providers

```http
GET https://api.example.com/users
Authorization: Bearer {{oauth:my_service}}
X-API-Key: {{vault:secret/api#key}}
X-Shortcut: {{refs:COMMON_TOKEN}}
```

**Configuration Files:**
- `oauth.toml` - OAuth service configurations
- `refs` - Variable reference mappings
- `.env` - Local environment variables (gitignored)

> See [PROVIDERS.md](PROVIDERS.md) for detailed provider documentation, security benefits, and configuration examples.

## Authentication Support 🔐

`hola.nvim` supports multiple authentication methods with automatic processing and template variable support.

### Basic Authentication

Simply write your credentials in readable format and the plugin handles the base64 encoding automatically.

**Basic Auth Example:**
```http
GET https://api.example.com/protected
Authorization: Basic username:password
```

The plugin automatically detects `Authorization: Basic username:password` headers and encodes them to `Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=` before sending.

**Works with variables:**
```http
GET https://api.example.com/protected
Authorization: Basic {{USERNAME}}:{{PASSWORD}}
```

### Bearer Token Authentication

Bearer tokens are used directly without modification, perfect for API keys and JWT tokens.

**Bearer Token Example:**
```http
GET https://api.example.com/data
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Works with variables:**
```http
GET https://api.example.com/data
Authorization: Bearer {{API_TOKEN}}
```

### API Key Authentication

API keys are passed directly without modification, perfect for services that require API key-based authentication.

**API Key Example:**
```http
GET https://api.example.com/users
Authorization: ApiKey sk-live_abc123def456ghi789
```

**Works with variables:**
```http
GET https://api.example.com/users
Authorization: ApiKey {{API_KEY}}
```

**Alternative header formats:**
```http
GET https://api.example.com/users
X-API-Key: {{API_KEY}}
```

Note: The `Authorization: ApiKey` format ensures consistent formatting, while custom headers like `X-API-Key` are passed through unchanged.

### OAuth 2.0 Server-to-Server Authentication

`hola.nvim` supports OAuth 2.0 client credentials flow for seamless server-to-server authentication with API gateways and enterprise services without requiring browser interaction.

**OAuth Token Example:**
```http
GET https://api.example.com/protected
Authorization: Bearer {{oauth:my_service}}
```

**Multi-environment Support:**
```http
### Development API
GET https://dev-api.example.com/data
Authorization: Bearer {{oauth:dev_service}}

### Production API
GET https://api.example.com/data
Authorization: Bearer {{oauth:prod_service}}
```

**Supported OAuth Services:**
- AWS Cognito
- Auth0
- Apigee
- Custom OAuth 2.0 providers

OAuth tokens are automatically obtained, cached, and refreshed as needed. Configuration is handled through `oauth.toml` files with service-specific settings.

> See [OAUTH.md](OAUTH.md) for detailed OAuth configuration, supported flows, and provider examples.


## Development: Join the "¡Hola!" Brigade! 🧑‍💻

Want to contribute to `hola.nvim`? Awesome! Here's how to get started:

*Note: If you are using nix and home-manager, try to use the native, unwrapped `nvim` binary for development.*

1.  Clone this repo: `git clone https://github.com/malev/hola.nvim`
2.  Open Neovim in the project root: `nvim -u scripts/init.lua examples.http`
3.  Run the tests: `make test` (Let's make sure everything is saying "¡Hola!" correctly!)
4.  Run `python scripts/server.py` to have a server for testing

We welcome pull requests and appreciate your contributions! 🙏

