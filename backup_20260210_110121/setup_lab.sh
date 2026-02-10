#!/bin/bash
# setup_lab.sh - Provisioning script for SAR-LAB
# Run this INSIDE the distrobox container.

set -e  # Exit on error

echo ">>> [1/6] UPGRADING NODE.JS TO V20..."
# Required for AI tools and Gemini CLI extensions
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

echo ">>> [2/6] INSTALLING 'UV' (Tool & Python Manager)..."
if [ ! -f "$HOME/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Update PATH immediately for the rest of this script session
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "UV already installed."
fi

echo ">>> [3/6] CONFIGURING NPM (User Space)..."
# Configure Node to run without sudo by using a local directory
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

echo ">>> [4/6] INSTALLING GEMINI CLI..."
if ! command -v gemini &> /dev/null; then
    npm install -g @google/gemini-cli
fi

echo ">>> [5/6] INSTALLING CONDUCTOR..."
gemini extensions install https://github.com/gemini-cli-extensions/conductor --auto-update || true

echo ">>> [6/6] CONFIGURING PYTHON 3.12 & STARSHIP (via UV)..."
# Use UV to install the Python 3.12 interpreter
uv python install 3.12

# Install starship Rust binary to local bin
curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir ~/.local/bin

# --- FINALIZING SHELL CONFIGURATION ---
# Ensure these paths and initializations persist in the container's .bashrc
add_to_bashrc() {
    local line="$1"
    if ! grep -qF "$line" "$HOME/.bashrc"; then
        echo "$line" >> "$HOME/.bashrc"
    fi
}

add_to_bashrc 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"'
add_to_bashrc 'export UV_VENV_IN_PROJECT=1'
add_to_bashrc 'eval "$(starship init bash)"'
add_to_bashrc 'eval "$(zoxide init bash)"'

echo ">>> SETUP COMPLETE. Restart the container or run 'source ~/.bashrc'."
