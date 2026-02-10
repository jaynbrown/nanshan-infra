#!/bin/bash
# setup_lab.sh - Health Check & Verification for SAR-LAB
# Run this INSIDE the distrobox container.

set -e

echo ">>> [1/4] VERIFYING SHARED PATHS..."
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

echo ">>> [2/4] CHECKING AI TOOLS..."
if command -v gemini &> /dev/null; then
    echo "✅ Gemini CLI found: $(gemini --version)"
else
    echo "❌ Gemini CLI not found. Ensure it is installed on the Host."
fi

echo ">>> [3/4] CHECKING PYTHON (UV)..."
if command -v uv &> /dev/null; then
    echo "✅ UV found: $(uv --version)"
    uv python install 3.12
else
    echo "❌ UV not found. Check Host installation."
fi

echo ">>> [4/4] REFRESHING SHELL CONFIG..."
# Chezmoi should already have applied the .bashrc
# This just ensures Starship is installed inside the container if needed
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir ~/.local/bin
fi

echo ">>> LAB VERIFICATION COMPLETE. Run 'source ~/.bashrc' if prompt hasn't changed."