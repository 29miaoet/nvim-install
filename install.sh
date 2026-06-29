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

info "Checking dependencies..."

packages=()

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

if ! command -v curl >/dev/null 2>&1; then
    warning "curl missing."
    packages+=("curl")
fi

info "Checking clipboard support..."

clipboard_package=""

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v wl-copy >/dev/null 2>&1; then
        success "Wayland clipboard found."
    else
        warning "Wayland clipboard missing."
        clipboard_package="wl-clipboard"
    fi
elif [[ -n "${DISPLAY:-}" ]]; then
    if command -v xclip >/dev/null 2>&1; then
        success "X11 clipboard found."
    elif command -v xsel >/dev/null 2>&1; then
        success "X11 clipboard found."
    else
        warning "X11 clipboard missing."
        clipboard_package="xclip"
    fi
else
    warning "No graphical session detected. Skipping clipboard provider."
fi

if [[ -n "$clipboard_package" ]]; then
    packages+=("$clipboard_package")
fi

if [[ ${#packages[@]} -gt 0 ]]; then
    info "Installing missing packages..."

    if ! command -v apt >/dev/null 2>&1; then
        error "apt not found. Install manually: ${packages[*]}"
    fi

    sudo apt update
    sudo apt install -y "${packages[@]}"

    success "Dependencies installed."
else
    success "All dependencies available."
fi

if [[ -e "$CONFIG_DIR" ]]; then
    BACKUP="${CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"

    warning "Existing config found. Backing up to $BACKUP"
    mv "$CONFIG_DIR" "$BACKUP"
fi

mkdir -p "$CONFIG_DIR/lua/plugins"

download() {
    local url="$1"
    local dest="$2"

    info "Downloading $(basename "$dest")"

    if ! curl -fsSL "$url" -o "$dest"; then
        error "Failed downloading $url"
    fi
}

download "$REPO_RAW/init.lua" "$CONFIG_DIR/init.lua"
download "$REPO_RAW/lazy-lock.json" "$CONFIG_DIR/lazy-lock.json"
download "$REPO_RAW/lua/plugins/colorscheme.lua" "$CONFIG_DIR/lua/plugins/colorscheme.lua"

success "Configuration installed."

info "Installing plugins..."
nvim --headless "+Lazy! sync" +qa
success "Plugins installed."

echo "Neovim setup complete."
