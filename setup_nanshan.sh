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
# 1. Create local bin if it doesn't exist
mkdir -p "$HOME/.local/bin"

# 2. Download and extract the latest static binary
# Using 25.01 as the current stable release
HELIX_VER="25.07.1"
curl -L "https://github.com/helix-editor/helix/releases/download/$HELIX_VER/helix-$HELIX_VER-x86_64-linux.tar.xz" -o /tmp/helix.tar.xz
tar -xJf /tmp/helix.tar.xz -C /tmp/

# 3. Move the binary and runtime to user-controlled paths
mv /tmp/helix-$HELIX_VER-x86_64-linux/hx "$HOME/.local/bin/"
mkdir -p "$HOME/.config/helix"
# Move runtime files so themes and LSP support work
cp -rn /tmp/helix-$HELIX_VER-x86_64-linux/runtime "$HOME/.config/helix/"

# Cleanup
rm -rf /tmp/helix.tar.xz /tmp/helix-$HELIX_VER-x86_64-linux

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
VAULT_POOL="vault"
VAULT_DISKS=(
    /dev/disk/by-id/ata-ST4000NM0035_WAICK95J
    /dev/disk/by-id/ata-ST4000NM0035_WAICK9AA
)

if sudo zpool list "$VAULT_POOL" >/dev/null 2>&1; then
    # Case 1: pool is already imported on this OS install
    echo "    Vault pool already imported. Skipping."
elif sudo zpool import -d /dev/disk/by-id 2>/dev/null | grep -qE "^[[:space:]]*pool: ${VAULT_POOL}$"; then
    # Case 2: pool exists on disk but isn't imported (e.g. after an OS reinstall).
    # NEVER re-create here; that would destroy the data. Import it instead.
    # -f is required because a fresh install has a new hostid; import -f does not modify data.
    echo "    Found existing vault pool on disk. Importing (data preserved)..."
    sudo zpool import -d /dev/disk/by-id -f "$VAULT_POOL"
else
    # Case 3: genuinely new disks. No -f: zpool will refuse (and set -e will abort)
    # if the disks carry existing partitions or filesystem labels.
    echo "    No existing vault pool found. Creating new mirror..."
    sudo zpool create -o ashift=12 "$VAULT_POOL" mirror "${VAULT_DISKS[@]}"
fi

echo ">>> Configuring Vault datasets and permissions..."
sudo zfs set compression=lz4 vault
sudo zfs set mountpoint=/mnt/vault vault
sudo zfs create -p vault/sar_data
sudo zfs create -p vault/homelab_backups
sudo zfs set quota=2T vault/homelab_backups
# Top-level ownership only: a recursive chown would clobber files written by NFS clients
sudo chown "$USER:$USER" /mnt/vault/sar_data

echo ">>> Configuring NFS Homelab Export..."
# Space-separated client IPs. 192.168.1.3 = suhaili (Proxmox Backup Server)
NFS_CLIENTS="192.168.1.3"
NFS_EXPORT_DIR="/mnt/vault/homelab_backups"
# PBS runs as 'backup' (uid/gid 34). all_squash maps every client user, root included,
# to that uid: no client gets root on the share, and PBS can still own its datastore.
NFS_OPTS="rw,sync,no_subtree_check,all_squash,anonuid=34,anongid=34"

sudo chown 34:34 "$NFS_EXPORT_DIR"

EXPORT_LINE="$NFS_EXPORT_DIR"
for client in $NFS_CLIENTS; do
    EXPORT_LINE+=" ${client}(${NFS_OPTS})"
done
# Own file under exports.d so re-runs replace the export instead of appending
sudo mkdir -p /etc/exports.d
echo "$EXPORT_LINE" | sudo tee /etc/exports.d/homelab_backups.exports >/dev/null
# Remove the legacy LAN-wide no_root_squash entry from /etc/exports, if present
sudo sed -i "\|^${NFS_EXPORT_DIR}[[:space:]]|d" /etc/exports
sudo exportfs -ra

# Firewall: NFSv4 (TCP 2049) only from the listed clients
for client in $NFS_CLIENTS; do
    sudo ufw allow from "$client" to any port 2049 proto tcp comment 'NFS homelab_backups'
done

echo ">>> Deploying ZFS Scrub Systemd Timer..."

# Define source and destination
SOURCE_DIR="$($HOME/.local/bin/chezmoi source-path)/systemd"
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
