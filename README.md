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
      -- Optional: customize JSON formatting
      json = {
        auto_format = true,     -- Auto-format JSON responses
        indent_size = 2,        -- Spaces for indentation
        sort_keys = true,       -- Sort object keys alphabetically
      },
    })
  end,
}
```

*Commands:*

  * `:HolaSend`: Unleash the request! 🚀
  * `:HolaSendSelected`: Send visually selected request block
  * `:HolaToggle`: Toggle between response body and metadata view
  * `:HolaClose`: Close response window
  * `:HolaFormatJson`: Toggle JSON formatting (formatted ↔ raw) ✨
  * `:HolaValidateJson`: Validate current JSON response syntax 🔍

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
* `:HolaValidateJson`: Check if your JSON response is syntactically valid

## Recommended Keymaps: Supercharge Your Workflow! ⚡

Here are some handy keymaps to make sending requests a breeze. Add these to your Neovim configuration:

```lua
local map = vim.keymap.set

-- Hola keymaps - Send it! 🚀
map("n", "<leader>hs", "<cmd>:HolaSend<cr>", { desc = "Send request" })
map("v", "<leader>hs", "<cmd>:HolaSendSelected<cr>", { desc = "Send selected request" })
-- Hola keymaps - Response navigation 👀
map({ "n", "v" }, "<leader>ht", "<cmd>:HolaToggle<cr>", { desc = "Toggle response body/metadata" })
map({ "n", "v" }, "<leader>hc", "<cmd>:HolaClose<cr>", { desc = "Close response window" })
-- Hola keymaps - JSON tools ✨
map({ "n", "v" }, "<leader>hf", "<cmd>:HolaFormatJson<cr>", { desc = "Toggle JSON formatting" })
map({ "n", "v" }, "<leader>hv", "<cmd>:HolaValidateJson<cr>", { desc = "Validate JSON" })
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
- **`:HolaValidateJson`** - Instant JSON syntax validation
- **Enhanced syntax highlighting** with proper JSON filetype detection
- **JSON folding support** for navigating large responses

### ⚙️ **Configuration**

Customize JSON formatting behavior in your Neovim config:

```lua
require("hola").setup({
  json = {
    auto_format = true,        -- Auto-format JSON responses
    indent_size = 2,           -- Spaces for indentation
    sort_keys = true,          -- Sort object keys alphabetically
    compact_arrays = true,     -- Keep simple arrays on one line
    max_array_length = 5,      -- Max items before expanding array
    enable_folding = true,     -- Enable JSON folding in buffer
  },
})
```

**Example formatted output:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "posts": [1, 2, 3]
    }
  ],
  "meta": {
    "count": 1,
    "status": "success"
  }
}
```

## Authentication Support 🔐

`hola.nvim` supports automatic Basic Authentication encoding. Simply write your credentials in readable format and the plugin handles the base64 encoding automatically.

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

## Power Up Your Requests with `.env` and Environment Variables! ⚙️

`hola.nvim` allows you to dynamically inject values into your `.http` files using placeholders that reference variables defined in `.env` files or environment variables. This is particularly useful for managing API keys, secrets, and other configuration that you don't want to hardcode directly in your request files.

**How it Works:**

When `hola.nvim` processes an `.http` file, it scans for placeholders in the format `{{VARIABLE_NAME}}`. For each placeholder found, it attempts to resolve the value by checking the following sources in order of precedence:

1. **`.env` Files:** `hola.nvim` will search for a `.env` file in the **current working directory** (the directory where you opened Neovim). If found, it will load the variables defined within this file.
2. **Environment Variables:** If a variable is not found in any loaded `.env` file, `hola.nvim` will then look for a matching environment variable set in your operating system.

**Example:**

Consider the following `.http` file:

```http
POST https://postman-echo.com/post
Content-Type: application/json
X-API-KEY: {{X_API_KEY}}
X-API-SECRET: {{X_API_SECRET}}

{
  "data": "some data",
  "apiKey": "{{API_KEY_FOR_JSON}}"
}
```

To populate the placeholders in this file, you can:

**1. Create a `.env` file in the same directory where you opened Neovim:**

```
X_API_KEY=your_actual_api_key
X_API_SECRET=your_super_secret
API_KEY_FOR_JSON=another_key_from_env
```

**2. Alternatively, you can set these variables as environment variables in your terminal before launching Neovim:**

```bash
export X_API_KEY="another_api_key_from_env"
export X_API_SECRET="even_more_secret"
export API_KEY_FOR_JSON="yet_another_key"
```

If no `.env` file is found or if a specific variable is not defined in the `.env` file, `hola.nvim` will fall back to checking your system's environment variables.

## Development: Join the "¡Hola!" Brigade! 🧑‍💻

Want to contribute to `hola.nvim`? Awesome! Here's how to get started:

*Note: If you are using nix and home-manager, try to use the native, unwrapped `nvim` binary for development.*

1.  Clone this repo: `git clone <your_repo_url>`
2.  Open Neovim in the project root: `nvim -u scripts/init.lua examples.http`
3.  Run the tests: `make test` (Let's make sure everything is saying "¡Hola!" correctly!)
4.  Run `python scripts/server.py` to have a server for testing

We welcome pull requests and appreciate your contributions! 🙏

