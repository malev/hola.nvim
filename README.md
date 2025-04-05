# Hola.nvim

> REST-client for Neovim with support to env vars and dotfiles

## Installation and requirements

```
{
  "malev/hola.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
}
```

Commands: `HolaSend`, `HolaShowWindow`, `HolaMaximizeWindow`.

## Example

```
# Get posts
GET https://jsonplaceholder.typicode.com/posts

# Create a new post
POST https://jsonplaceholder.typicode.com/posts

{"title": "hello"}

# Delete post
DELETE https://jsonplaceholder.typicode.com/posts/1

```

## Usage

Open the a file with requests, like the example above. Navigate to the request you want to send and call the command `:HolaSend`.
The reponse will be displayed in a panel on the right. If you need to see the headers, you can call `:HolaShowWindow`,
and if there are too many headers, and you need more space, you can maximize it with `:HolaMaximizeWindow`.

Recommended keymaps:

```
local map = vim.keymap.set

-- Hola keymaps
map("n", "<leader>hs", "<cmd>:HolaSend<cr>", { desc = "Send request" })
map("v", "<leader>hs", "<cmd>:HolaSendSelected<cr>", { desc = "Send selected request" })
map({ "n", "v" }, "<leader>hw", "<cmd>:HolaShowWindow<cr>", { desc = "Show metadata window" })
map({ "n", "v" }, "<leader>hm", "<cmd>:HolaMaximizeWindow<cr>", { desc = "Maximize metadata window" })

```

## `.env` File and Environment Variables Support

`hola.nvim` allows you to dynamically inject values into your `.http` files using placeholders that reference variables defined in `.env` files or environment variables. This is particularly useful for managing API keys, secrets, and other configuration that you don't want to hardcode directly in your request files.

**How it Works:**

When `hola.nvim` processes an `.http` file, it scans for placeholders in the format `{{VARIABLE_NAME}}`. For each placeholder found, it attempts to resolve the value by checking the following sources in order of precedence:

1. **`.env` Files:** `hola.nvim` will search for a `.env` file in the **current working directory** (the directory where you opened Neovim). If found, it will load the variables defined within this file.
2. **Environment Variables:** If a variable is not found in any loaded `.env` file, `hola.nvim` will then look for a matching environment variable set in your operating system.

**Example:**

Consider the following `.http` file:

```
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

When you execute this `.http` request using `hola.nvim`, the `{{X_API_KEY}}` placeholder will be replaced with `your_actual_api_key`, `{{X_API_SECRET}}` with `your_super_secret`, and `{{API_KEY_FOR_JSON}}` with `another_key_from_env`.

**2. Alternatively, you can set these variables as environment variables in your terminal before launching Neovim:**

```bash
export X_API_KEY="another_api_key_from_env"
export X_API_SECRET="even_more_secret"
export API_KEY_FOR_JSON="yet_another_key"
nvim .
```

If no `.env` file is found or if a specific variable is not defined in the `.env` file, `hola.nvim` will fall back to checking your system's environment variables.

## Development

Clone this repo and open nvim with `nvim -u scripts/init.lua examples.http`. Use `make test` will run all the tests.

