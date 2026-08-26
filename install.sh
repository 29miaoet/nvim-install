#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/29miaoet/nvim-install/refs/heads/master"
CONFIG_DIR="$HOME/.config/nvim"

info() {
    echo "[INFO] $1"
}

success() {
    echo "[DONE] $1"
}

warning() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
    exit 1
}

info "Checking operating system..."

if [[ "$(uname -s)" != "Linux" ]]; then
    error "This installer is intended for Linux."
fi

if ! command -v apt >/dev/null 2>&1; then
    error "apt not found. This installer currently supports Debian/Ubuntu-based Linux distributions."
fi

if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is required to install system packages."
fi

info "Checking dependencies..."

packages=()

# Core tools

if command -v nvim >/dev/null 2>&1; then
    success "Neovim found: $(nvim --version | head -n1)"
else
    warning "Neovim missing."
    packages+=("neovim")
fi

if command -v git >/dev/null 2>&1; then
    success "Git found: $(git --version)"
else
    warning "Git missing."
    packages+=("git")
fi

if command -v curl >/dev/null 2>&1; then
    success "curl found."
else
    warning "curl missing."
    packages+=("curl")
fi

# Node.js / npm

if command -v node >/dev/null 2>&1; then
    success "Node.js found: $(node --version)"
else
    warning "Node.js missing."
    packages+=("nodejs")
fi

if command -v npm >/dev/null 2>&1; then
    success "npm found: $(npm --version)"
else
    warning "npm missing."
    packages+=("npm")
fi

# Python

if command -v python3 >/dev/null 2>&1; then
    success "Python found: $(python3 --version)"
else
    warning "Python missing."
    packages+=("python3")
fi

# C/C++ development tools

if command -v g++ >/dev/null 2>&1; then
    success "g++ found: $(g++ --version | head -n1)"
else
    warning "g++ missing."
    packages+=("g++")
fi

if command -v make >/dev/null 2>&1; then
    success "make found."
else
    warning "make missing."
    packages+=("make")
fi

# Clipboard support

info "Checking clipboard support..."

clipboard_packages=()

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v wl-copy >/dev/null 2>&1; then
        success "Wayland clipboard found."
    else
        warning "Wayland clipboard missing."
        clipboard_packages+=("wl-clipboard")
    fi

elif [[ -n "${DISPLAY:-}" ]]; then
    if command -v xclip >/dev/null 2>&1; then
        success "X11 clipboard found: xclip"
    elif command -v xsel >/dev/null 2>&1; then
        success "X11 clipboard found: xsel"
    else
        warning "X11 clipboard missing."
        clipboard_packages+=("xclip")
    fi

else
    warning "No graphical session detected. Skipping clipboard provider."
fi

packages+=("${clipboard_packages[@]}")

# xdg-open

if command -v xdg-open >/dev/null 2>&1; then
    success "xdg-open found."
else
    warning "xdg-open missing."
    packages+=("xdg-utils")
fi

# Install missing apt packages

if [[ ${#packages[@]} -gt 0 ]]; then
    info "Installing missing packages..."

    # Remove duplicate package names.
    mapfile -t packages < <(printf '%s\n' "${packages[@]}" | sort -u)

    sudo apt update
    sudo apt install -y "${packages[@]}"

    success "System dependencies installed."
else
    success "All system dependencies available."
fi

# Verify required commands

info "Verifying required commands..."

required_commands=(
    nvim
    git
    curl
    node
    npm
    python3
    g++
    make
)

for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        error "Required command not found after installation: $command_name"
    fi
done

success "Required commands verified."

# Install global Node.js development tools

info "Checking TypeScript..."

if command -v tsc >/dev/null 2>&1; then
    success "TypeScript found: $(tsc --version)"
else
    warning "TypeScript missing."
    info "Installing TypeScript globally..."

    sudo npm install -g typescript

    success "TypeScript installed."
fi

info "Checking TypeScript LSP support..."

if tsc --help 2>/dev/null | grep -q -- "--lsp"; then
    success "TypeScript native LSP detected."
else
    warning "Installed TypeScript does not expose --lsp."
    warning "TypeScript 7 or newer is required for tsc --lsp --stdio."
fi

# Install tsx

if command -v tsx >/dev/null 2>&1; then
    success "tsx found: $(tsx --version 2>/dev/null || true)"
else
    warning "tsx missing."
    info "Installing tsx globally..."

    sudo npm install -g tsx

    success "tsx installed."
fi

# Install basedpyright

if command -v basedpyright-langserver >/dev/null 2>&1; then
    success "basedpyright found."
else
    warning "basedpyright missing."
    info "Installing basedpyright..."

    python3 -m pip install --user basedpyright

    success "basedpyright installed."
fi

# Backup existing Neovim configuration

if [[ -e "$CONFIG_DIR" ]]; then
    BACKUP="${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

    warning "Existing config found. Backing up to $BACKUP"
    mv "$CONFIG_DIR" "$BACKUP"
fi

mkdir -p "$CONFIG_DIR/lua/plugins"

# Download configuration

download() {
    local url="$1"
    local dest="$2"

    info "Downloading $(basename "$dest")"

    if ! curl -fsSL "$url" -o "$dest"; then
        error "Failed downloading $url"
    fi
}

download "$REPO_RAW/init.lua" \
    "$CONFIG_DIR/init.lua"

download "$REPO_RAW/lazy-lock.json" \
    "$CONFIG_DIR/lazy-lock.json"

download "$REPO_RAW/lua/plugins/colorscheme.lua" \
    "$CONFIG_DIR/lua/plugins/colorscheme.lua"

success "Configuration installed."

# Install Neovim plugins

info "Installing plugins..."

if ! nvim --headless "+Lazy! sync" +qa; then
    error "Plugin installation failed."
fi

success "Plugins installed."

# Final verification
info "Running Neovim health check..."

if nvim --headless "+checkhealth" +qa >/dev/null 2>&1; then
    success "Neovim health check completed."
else
    warning "Neovim health check reported issues."
fi

echo
echo "Neovim setup complete."
echo
echo "Installed versions:"
echo "  Neovim:    $(nvim --version | head -n1)"
echo "  Node.js:   $(node --version)"
echo "  npm:       $(npm --version)"
echo "  TypeScript: $(tsc --version 2>/dev/null || echo 'unavailable')"
echo "  Python:    $(python3 --version)"
echo "  Git:       $(git --version)"
echo

