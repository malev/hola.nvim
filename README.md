# Hola.nvim

> REST-client for Neovim

## Installation and requirements

```
{
  "malev/hola.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
}
```

Commands: `HolaSend`, `HolaToggle`, `HolaHide`.

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

## Development

Clone this repo and open nvim with `nvim -u scripts/init.lua examples.http`. Use `make test` will run all the tests.

