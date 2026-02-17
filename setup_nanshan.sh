#!/bin/bash
# NANSHAN PROVISIONING v4.1 (Atomic DRL Edition)
# Stack: Pop!_OS + SSH + Tailscale + Node20 + Gemini + UV + Chezmoi + Helix + Atuin

set -e

echo ">>> [1/11] HOST SYSTEM HYGIENE..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential distrobox podman ripgrep fd-find openssh-server

echo ">>> [2/11] SECURING THE PERIMETER (Firewall & SSH)..."
sudo systemctl enable --now ssh
sudo ufw allow ssh
sudo ufw allow 41641/udp # Tailscale Port
# Enable firewall
echo "y" | sudo ufw enable
sudo ufw reload

echo ">>> [3/11] CONNECTING TO TAILSCALE..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo tailscale up --ssh --accept-dns=true --operator=$USER
sudo ufw allow in on tailscale0

echo ">>> [4/11] INSTALLING AI COMMAND CENTER (Node.js + Gemini)..."
# 1. Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Configure NPM for User Space
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

# 3. Fix Permissions
sudo chown -R $(whoami):$(whoami) "$HOME/.npm-global"
sudo chown -R $(whoami):$(whoami) "$HOME/.npm" 2>/dev/null || true

# 4. Install Gemini & Conductor (Host-only, shared with containers)
npm install -g @google/gemini-cli
gemini extensions install https://github.com/gemini-cli-extensions/conductor --auto-update || true

echo ">>> [5/11] INSTALLING 'UV' & PYTHON TOOLS..."
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"
uv tool install ruff
uv tool install basedpyright

echo ">>> [6/11] INSTALLING CHEZMOI (Dotfile Manager)..."
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if [ ! -d "$HOME/.local/share/chezmoi" ]; then
    echo "Restoring dotfiles from GitHub..."
    # Try to clone repo and apply immediately; fall back to empty init if repo missing
    chezmoi init --apply https://github.com/jaynbrown/dotfiles.git || chezmoi init
else
    echo "Chezmoi vault already exists. Pulling latest changes..."
    chezmoi update
fi

echo ">>> [7/11] INSTALLING NAVIGATION (Zoxide + FZF + Atuin)..."
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all --key-bindings --completion --no-update-rc
fi

if ! command -v atuin &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | sh
fi

echo ">>> Locking in Atuin pre-exec hook..."
# Download the hook script silently
curl -sLo ~/.bash-preexec.sh https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh

echo ">>> [8/11] INSTALLING STARSHIP (Prompt)..."
curl -sS https://starship.rs/install.sh | sh -s -- -y

echo ">>> [9/11] CONFIGURING HELIX (Editor)..."
sudo add-apt-repository ppa:maveonair/helix-editor -y
sudo apt update && sudo apt install -y helix

echo ">>> [10/11] INSTALLING GUI APPS (FLATPAK)..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub dev.zed.Zed io.github.zen_browser.zen com.discordapp.Discord md.obsidian.Obsidian org.qgis.qgis

echo ">>> [11/11] FINALIZING CONFIGURATION VIA CHEZMOI..."
git config --global init.defaultBranch main
git config --global user.name "jaynbrown"
git config --global user.email "58671324+jaynbrown@users.noreply.github.com"

# Apply dotfiles to ensure clean .bashrc and configs
~/.local/bin/chezmoi apply --force

# ==========================================
# ZFS VAULT & NFS BACKUP TARGET
# ==========================================
echo ">>> Installing ZFS and NFS dependencies..."
sudo apt install -y zfsutils-linux zfs-dkms linux-headers-$(uname -r) nfs-kernel-server

echo ">>> Configuring ZFS ARC limit to 4GB..."
if ! grep -qF "zfs_arc_max=4294967296" /etc/modprobe.d/zfs.conf 2>/dev/null; then
    echo "options zfs zfs_arc_max=4294967296" | sudo tee /etc/modprobe.d/zfs.conf
    sudo update-initramfs -u -k all
fi

echo ">>> Assembling ZFS Vault..."
# Only attempt to create the pool if it doesn't already exist
if ! zpool list vault >/dev/null 2>&1; then
    sudo zpool create -f -o ashift=12 vault mirror \
        /dev/disk/by-id/ata-ST4000NM0035_WAICK95J \
        /dev/disk/by-id/ata-ST4000NM0035_WAICK9AA
else
    echo "    Vault pool already exists. Skipping creation."
fi

echo ">>> Configuring Vault datasets and permissions..."
sudo zfs set compression=lz4 vault
sudo zfs set mountpoint=/mnt/vault vault
sudo zfs create -p vault/sar_data
sudo zfs create -p vault/homelab_backups
sudo zfs set quota=2T vault/homelab_backups
sudo chown -R $USER:$USER /mnt/vault

echo ">>> Configuring NFS Homelab Export..."
# Only add the export line if it's missing
EXPORT_LINE="/mnt/vault/homelab_backups 192.168.1.00/24(rw,async,no_subtree_check,no_root_squash)"
if ! grep -qF "/mnt/vault/homelab_backups" /etc/exports; then
    echo "$EXPORT_LINE" | sudo tee -a /etc/exports
    sudo exportfs -arv
fi

echo ">>> Deploying ZFS Scrub Systemd Timer..."

# Define source and destination
SOURCE_DIR="$(chezmoi source-path)/systemd"
DEST_DIR="/etc/systemd/system"

sudo cp "$SOURCE_DIR/zfs-scrub-vault.service" "$DEST_DIR/"
sudo cp "$SOURCE_DIR/zfs-scrub-vault.timer" "$DEST_DIR/"

# Set correct root permissions
sudo chown root:root "$DEST_DIR/zfs-scrub-vault."*
sudo chmod 644 "$DEST_DIR/zfs-scrub-vault."*

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable --now zfs-scrub-vault.timer

echo ">>> DONE. PLEASE REBOOT OR RUN: source ~/.bashrc"
