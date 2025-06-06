# Hola.nvim - Context and Guidelines

## Build, Lint, and Test Commands
- To build or compile the project, use the provided Makefile: `make` or `make build`
- To run tests, execute: `make test`
- To run a specific test, use a test runner command compatible with the framework used (details not specified, likely via `make test` with arguments)
- To lint the codebase, run: `make lint`

## Code Style Guidelines
- Use consistent indentation (preferably two spaces)
- Import statements should be grouped at the top of files, organized logically
- Follow idiomatic Lua style: snake_case for variables and functions, PascalCase for types and classes
- Use explicit type annotations where possible
- Handle errors gracefully; prefer Lua's pcall or similar patterns
- Write clear, descriptive variable and function names
- Maintain modularity; keep functions small and focused
- Document exported functions and modules clearly

## Additional Rules
- Follow cursor rules from `.cursor/rules/` or `.cursorrules` if present
- Follow Copilot instructions from `.github/copilot-instructions.md` if present

> Note: Ensure to update this file if new commands or style rules are adopted.