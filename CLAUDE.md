# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hola.nvim is a Neovim plugin for sending HTTP requests directly from the editor. It's designed as a REST client that operates on `.http` files with comprehensive configuration management through a provider-based system supporting environment variables, OAuth 2.0, and HashiCorp Vault.

## Development Commands

### Build and Test
- `make test` - Run test suite using plenary.nvim (requires deps/plenary.nvim)
- `make lint` - Run luacheck linting on lua/hola, plugin/, and spec/ directories
- `make deps/plenary.nvim` - Clone plenary.nvim dependency if not present

### Development Setup
To develop the plugin:
1. Open Neovim in project root with: `nvim -u scripts/init.lua examples.http`
2. This loads the plugin in a minimal environment for testing
3. Run `python scripts/server.py` to start a test server for development

## Code Architecture

### Core Components

**Main Entry Point** (`lua/hola/init.lua`)
- Orchestrates the HTTP request workflow
- Manages visual feedback (virtual text showing request status)
- Coordinates between parsing, provider resolution, and request execution
- Initializes the provider-based resolution system

**Request Processing Pipeline:**
1. `utils.get_request_under_cursor()` - Extracts HTTP request text from cursor position
2. `resolution.resolve_variables()` - Resolves template variables using provider system
3. `utils.parse_request()` - Parses HTTP request syntax into structured data
4. `request.execute()` - Executes async HTTP request via plenary.curl
5. `ui.display_response()` - Shows response in split window with JSON formatting

**Key Modules:**

- **`lua/hola/utils.lua`** - Core parsing logic
  - HTTP request parsing with separator detection (`###` lines)
  - Header normalization and response filetype detection
  - Authentication header processing (Basic Auth encoding)

- **`lua/hola/resolution.lua`** - Provider-based variable resolution
  - Unified template variable resolution using `{{provider:identifier}}` syntax
  - Supports env, vault, oauth, and refs providers
  - Centralized configuration management

- **`lua/hola/request.lua`** - HTTP execution
  - Async requests using plenary.curl
  - Error handling and timeout management
  - Response post-processing

- **`lua/hola/ui.lua`** - User interface
  - Split window management for response display
  - Toggle between response body and metadata/headers
  - JSON formatting and syntax highlighting

- **`lua/hola/json.lua`** - JSON processing
  - Automatic JSON formatting with configurable options
  - Smart array handling (compact vs expanded)
  - Key sorting and indentation

- **`lua/hola/oauth.lua`** - OAuth 2.0 integration
  - Client credentials flow implementation
  - Token caching and automatic refresh
  - Support for multiple OAuth providers

- **`lua/hola/config.lua`** - Configuration management
  - Plugin configuration with defaults
  - Provider-specific settings
  - Health check integration

- **`lua/hola/virtual_text.lua`** - Visual feedback
  - Status indicators during request execution
  - Progress and error messages

**Provider System:**
- **env**: Environment variables and `.env` files
- **vault**: HashiCorp Vault secret retrieval
- **oauth**: OAuth 2.0 token management
- **refs**: Reference aliases to other providers

**Request File Format:**
- Requests separated by `###` lines
- First line: `METHOD URL [HTTP/Version]`
- Headers as `Key: Value` pairs
- Blank line separates headers from body
- Template variables: `{{provider:identifier}}` (e.g., `{{env:API_KEY}}`, `{{oauth:service}}`)

### Command Interface

**Active Commands:**
- `:HolaSend` - Send request under cursor
- `:HolaToggle` - Toggle between response body and metadata view
- `:HolaClose` - Close response window
- `:HolaFormatJson` - Toggle JSON formatting (formatted ↔ raw)


### Dependencies

- **plenary.nvim** - Required for async curl operations and testing framework
- Minimum Neovim version: 0.7.0

### Testing

Tests are located in `tests/` directory and use plenary.nvim's test framework. Key test areas:
- HTTP request parsing and validation
- Provider-based variable resolution (env, vault, oauth, refs)
- JSON formatting and processing
- OAuth token management
- Virtual text integration
- Full integration testing