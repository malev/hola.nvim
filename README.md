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

