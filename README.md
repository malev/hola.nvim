# Hola.nvim: Your In-Neovim REST Command Center

> Send HTTP requests without leaving the comfort of your editor, with built-in environment and dotenv support!

## Installation: Get Ready to Say "¡Hola!" 👋

Just add this to your `plugins` table in your Neovim configuration (using your preferred plugin manager):

```lua
{
  "malev/hola.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
}
```

*Commands:*

  * `:HolaSend`: Unleash the request! 🚀
  * `:HolaShowWindow`: Peek behind the curtain (see those headers!). 👀
  * `:HolaMaximizeWindow`: Go full screen for header inspection. 🔍

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

* `:HolaShowWindow`: Want to see the raw headers and metadata? This command will pop open a window with all the juicy details.
* `:HolaMaximizeWindow`: Overwhelmed by headers? Maximize the metadata window for a better view.

## Recommended Keymaps: Supercharge Your Workflow! ⚡

Here are some handy keymaps to make sending requests a breeze. Add these to your Neovim configuration:

```lua
local map = vim.keymap.set

-- Hola keymaps - Send it! 🚀
map("n", "<leader>hs", "<cmd>:HolaSend<cr>", { desc = "Send request" })
map("v", "<leader>hs", "<cmd>:HolaSendSelected<cr>", { desc = "Send selected request" })
-- Hola keymaps - Peek at the details 👀
map({ "n", "v" }, "<leader>hw", "<cmd>:HolaShowWindow<cr>", { desc = "Show metadata window" })
-- Hola keymaps - Maximize for clarity 🔍
map({ "n", "v" }, "<leader>hm", "<cmd>:HolaMaximizeWindow<cr>", { desc = "Maximize metadata window" })
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

We welcome pull requests and appreciate your contributions! 🙏

