#!/bin/bash
# NANSHAN PROVISIONING v4.0 (The Dotfiles Edition)
# Stack: Pop!_OS + SSH + Tailscale + Node20 + Gemini + UV + Chezmoi + Helix

set -e

# Helper: Safely append to .bashrc
add_to_bashrc() {
    local line="$1"
    if ! grep -qF "$line" "$HOME/.bashrc"; then
        echo "$line" >> "$HOME/.bashrc"
    fi
}

echo ">>> [1/11] HOST SYSTEM HYGIENE..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential distrobox podman ripgrep fd-find openssh-server

echo ">>> [2/11] SECURING THE PERIMETER (Firewall & SSH)..."
sudo systemctl enable --now ssh
sudo ufw allow ssh
# CRITICAL: We must actually enable the firewall
echo "y" | sudo ufw enable
sudo ufw reload

echo ">>> [3/11] CONNECTING TO TAILSCALE..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
# Note: This may pause the script waiting for browser auth if not already auth'd
sudo tailscale up --ssh --accept-dns=true --operator=$USER
# Trust the Tailscale interface (optional but recommended)
sudo ufw allow in on tailscale0

echo ">>> [4/11] INSTALLING AI COMMAND CENTER (Node.js + Gemini)..."
# 1. Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Configure NPM for User Space
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

# 3. Fix Permissions (Crucial if sudo was used before)
sudo chown -R $(whoami):$(whoami) "$HOME/.npm-global"
sudo chown -R $(whoami):$(whoami) "$HOME/.npm" 2>/dev/null || true

# 4. Install Gemini & Conductor
npm install -g @google/gemini-cli
gemini extensions install https://github.com/gemini-cli-extensions/conductor --auto-update || true

echo ">>> [5/11] INSTALLING 'UV' & PYTHON TOOLS..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"
uv tool install ruff
uv tool install basedpyright

echo ">>> [6/11] INSTALLING CHEZMOI (Dotfile Manager)..."
# Installs to ~/.local/bin
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Initialize a new local vault if one doesn't exist
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo "Initializing new Chezmoi vault..."
    chezmoi init
else
    echo "Chezmoi vault already exists. Skipping init."
fi

echo ">>> [7/11] INSTALLING NAVIGATION (Zoxide + FZF)..."
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all --key-bindings --completion --no-update-rc
fi

echo ">>> [8/11] INSTALLING STARSHIP (Prompt)..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo ">>> [9/11] CONFIGURING HELIX (Editor)..."
sudo add-apt-repository ppa:maveonair/helix-editor -y
sudo apt update && sudo apt install -y helix
mkdir -p ~/.config/helix

# Inject Languages Config (Will be managed by Chezmoi later)
cat <<EOF > ~/.config/helix/languages.toml
[[language]]
name = "python"
language-servers = [ "basedpyright", "ruff" ]
auto-format = true

[language-server.ruff]
command = "ruff"
args = ["server", "--preview"]

[language-server.basedpyright]
command = "basedpyright-langserver"
args = ["--stdio"]

[language-server.basedpyright.config.basedpyright.analysis]
typeCheckingMode = "standard"
EOF

# Inject Editor Config
cat <<EOF > ~/.config/helix/config.toml
theme = "tokyonight"
[editor]
line-number = "relative"
mouse = false
cursorline = true
[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"
[editor.file-picker]
hidden = false
EOF

echo ">>> [10/11] INSTALLING GUI APPS (FLATPAK)..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub dev.zed.Zed io.github.zen_browser.zen com.discordapp.Discord md.obsidian.Obsidian org.qgis.qgis

echo ">>> [11/11] FINALIZING DOTFILES..."
git config --global init.defaultBranch main
git config --global user.name "jaynbrown"
git config --global user.email "58671324+jaynbrown@users.noreply.github.com"

add_to_bashrc '# --- USER PATHS ---'
add_to_bashrc 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"'
add_to_bashrc 'eval "$(starship init bash)"'
add_to_bashrc 'eval "$(zoxide init bash)"'

echo ">>> DONE. PLEASE RUN: source ~/.bashrc"
