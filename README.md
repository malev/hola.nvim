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

## Development

Clone this repo and open nvim with `nvim -u scripts/init.lua examples.http`. Use `make test` will run all the tests.

