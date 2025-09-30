#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}Running tests and style checks for hola.nvim...${NC}"
echo

# Change to project root
cd "$PROJECT_ROOT"

# Function to print section headers
print_section() {
    echo -e "${YELLOW}=== $1 ===${NC}"
}

# Function to handle errors
handle_error() {
    echo -e "${RED}Error: $1${NC}"
    exit 1
}

# Check if stylua is installed
if ! command -v stylua &> /dev/null; then
    handle_error "stylua is not installed. Install with: nix-env -iA nixpkgs.stylua"
fi

# Check if nvim is installed
if ! command -v nvim &> /dev/null; then
    handle_error "nvim is not installed"
fi

# Ensure plenary.nvim dependency is available
print_section "Installing dependencies"
if [ ! -d "deps/plenary.nvim" ]; then
    echo "Installing plenary.nvim dependency..."
    mkdir -p deps
    git clone --filter=blob:none https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim || handle_error "Failed to install plenary.nvim"
else
    echo "plenary.nvim already installed"
fi
echo -e "${GREEN}Dependencies OK${NC}"
echo

# Run style checks
print_section "Running style checks (stylua)"
if stylua --check lua/ plugin/; then
    echo -e "${GREEN}Style checks passed${NC}"
else
    handle_error "Style checks failed. Run 'stylua lua/ plugin/' to fix formatting"
fi
echo

# Run tests
print_section "Running tests"
if nvim --headless -u scripts/init.lua -c "PlenaryBustedDirectory ./tests {minimal_init='./scripts/init.lua'}"; then
    echo -e "${GREEN}Tests passed${NC}"
else
    handle_error "Tests failed"
fi
echo

echo -e "${GREEN}All checks passed! ✓${NC}"