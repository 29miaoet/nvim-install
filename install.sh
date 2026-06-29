#!/usr/bin/env bash
set -euo pipefail

# Neovim config installer
CONFIG_DIR="$HOME/.config/nvim"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

success() {
    echo -e "\033[1;32m[DONE]\033[0m $1"
}

warning() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

require_file() {
    if [[ ! -e "$1" ]]; then
        error "Missing required file: $1"
        exit 1
    fi
}

# Check OS
info "Checking operating system..."
if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect Linux distribution."
    exit 1
fi
source /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID_LIKE" != *"debian"* ]]; then
    warning "This installer was written for Ubuntu/Debian systems."
fi
success "OS detected: $PRETTY_NAME"

# Check dependencies
install_packages=()
info "Checking dependencies..."
if command -v nvim >/dev/null 2>&1; then
    success "Neovim found: $(nvim --version | head -n1)"
else
    warning "Neovim not found."
    install_packages+=("neovim")
fi
if command -v git >/dev/null 2>&1; then
    success "Git found: $(git --version)"
else
    warning "Git not found."
    install_packages+=("git")
fi

# Install missing packages
if [[ ${#install_packages[@]} -gt 0 ]]; then
    info "Installing missing packages..."
    if ! command -v apt >/dev/null 2>&1; then
        error "apt package manager not found. Install manually:"
        printf '  %s\n' "${install_packages[@]}"
        exit 1
    fi
    sudo apt update
    sudo apt install -y "${install_packages[@]}"
    success "Dependencies installed."
else
    success "All dependencies already installed."
fi

# Validate config files
info "Checking configuration files..."
require_file "$SCRIPT_DIR/init.lua"
require_file "$SCRIPT_DIR/lazy-lock.json"
if [[ ! -d "$SCRIPT_DIR/lua" ]]; then
    error "Missing lua directory."
    exit 1
fi
success "Configuration files verified."

# Backup existing config
info "Checking existing Neovim configuration..."
if [[ -e "$CONFIG_DIR" ]]; then
    BACKUP="${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    warning "Existing config detected:"
    echo "  $CONFIG_DIR"
    echo "Backing up to:"
    echo "  $BACKUP"
    mv "$CONFIG_DIR" "$BACKUP"
    success "Backup created."
else
    success "No existing config found."
fi

# Install config
info "Installing Neovim configuration..."
mkdir -p "$CONFIG_DIR"
cp "$SCRIPT_DIR/init.lua" "$CONFIG_DIR/"
cp "$SCRIPT_DIR/lazy-lock.json" "$CONFIG_DIR/"
cp -r "$SCRIPT_DIR/lua" "$CONFIG_DIR/"
success "Configuration copied."

# Install plugins
info "Installing Neovim plugins..."
nvim --headless "+Lazy! sync" +qa
success "Plugins installed."

# Finished
echo
echo " Neovim installation complete!"
echo
echo "Config location:"
echo "  $CONFIG_DIR"
echo
