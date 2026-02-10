# NANSHAN WORKSTATION CONFIGURATION
**Status:** Active | **Role:** Deep Learning & SAR Operations | **Owner:** Jason

## 1. Hardware Specifications
* **Model:** Lenovo ThinkStation P620
* **CPU:** AMD Threadripper Pro 5965WX (24 Cores / 48 Threads)
* **RAM:** 64GB DDR4-3200 ECC (4x 16GB)
* **GPU:** NVIDIA GeForce RTX 3060 (12GB VRAM)
* **Storage (Tier 1 - OS/Hot):** 2TB NVMe SSD (Pop!_OS Root)
* **(Planned) Storage (Tier 2 - OS/Hot):** 1TB NVMe SSD (Pop!_OS Root) will move home to 2TB NVMe
* **(Planned) Storage (Tier 3 - Data):** 2x 4TB Seagate Enterprise HDD (ZFS Mirror / Data Vault)
* **Networking:** Aquantia 10GbE + Intel Wi-Fi 6

---

## 2. Operational Philosophy
Nanshan follows an **"Atomic" Infrastructure-as-Code** philosophy. The goal is to keep the Host OS distinct from the Development Environment to ensure stability and rapid recovery.

### The Three Layers
1.  **Layer 0: Host OS (Pop!_OS)**
    * **Role:** Bare metal driver management (NVIDIA, Network), Container Runtime, and Encryption.
    * **State:** *Immutable-ish.* We rarely install software here via `apt`.
    * **Tools:** `git`, `helix`, `uv`, `docker/podman`, `starlight`, `ruff`, `basedpyright`
2.  **Layer 1: GUI Applications (Flatpak)**
    * **Role:** User-facing tools (Browsers, IDEs, Chat).
    * **Isolation:** Sandboxed from the OS. Updated independently.
    * **Apps:** Zen Browser, Zed IDE, Obsidian, Discord, QGIS.
3.  **Layer 2: The SAR Lab (Distrobox)**
    * **Role:** The actual workspace. Deep Learning, Python 3.12, Geospatial Tools.
    * **State:** *Ephemeral.* Created and destroyed via `distrobox.ini`.
    * **Tech:** Ubuntu 24.04 Image + `uv` (Python) + Gemini CLI (Agent).

---

## 3. Directory Structure (PARA)
Filesystem layout optimized for context separation.

```text
/home/jason/
├── Projects/          # Active Code (Git Repos)
│   ├── nanshan-infra/   # THIS REPO (Scripts & Dotfiles)
│   ├── marlow/         # DRL Agent
├── Areas/             # Ongoing Responsibility (Admin, Docs)
├── Resources/         # Static Assets
│   ├── docs/
│   ├── papers/    
└── Archives/          # Cold Storage

4. Provisioning Scripts
A. Host Provisioning (setup_nanshan.sh)

Run this ONCE after a fresh Pop!_OS install to hydrate the host.
Bash

#!/bin/bash
# NANSHAN PROVISIONING v4.1
# Stack: Pop!_OS + SSH + Tailscale + Node20 + Gemini + UV + Chezmoi + Helix

set -e

echo ">>> [1/11] HOST SYSTEM HYGIENE..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git build-essential distrobox podman ripgrep fd-find openssh-server

# ... (rest of the script as in setup_nanshan.sh)

echo ">>> [2/6] INSTALLING 'UV' (Python Manager)..."
curl -LsSf [https://astral.sh/uv/install.sh](https://astral.sh/uv/install.sh) | sh
source $HOME/.cargo/env 2>/dev/null || source $HOME/.local/bin/env

echo ">>> [3/6] INSTALLING HELIX (Editor)..."
sudo add-apt-repository ppa:maveonair/helix-editor -y
sudo apt update && sudo apt install -y helix

echo ">>> [4/6] INSTALLING GUI APPS (FLATPAK)..."
flatpak remote-add --if-not-exists flathub [https://flathub.org/repo/flathub.flatpakrepo](https://flathub.org/repo/flathub.flatpakrepo)
# Remove conflicting user remote if it exists
flatpak remote-delete --user flathub || true 

flatpak install -y flathub dev.zed.Zed
flatpak install -y flathub io.github.zen_browser.zen
flatpak install -y flathub com.discordapp.Discord
flatpak install -y flathub md.obsidian.Obsidian
flatpak install -y flathub org.qgis.qgis

echo ">>> [5/6] CONFIGURING GIT..."
git config --global init.defaultBranch main
git config --global user.name "jaynbrown"
git config --global user.email "58671324+jaynbrown@users.noreply.github.com"

echo ">>> [6/6] DONE. REBOOT REQUIRED."

B. Lab Definition (distrobox.ini)

Run distrobox assemble create --file distrobox.ini to build the lab.
Ini, TOML

[sar-lab]
image=ubuntu:24.04
pull=true
nvidia=true
start_now=true

# --- SYSTEM DEPENDENCIES ---
additional_packages="git curl wget build-essential clang"
additional_packages="gdal-bin libgdal-dev libnetcdf-dev libhdf5-dev"
additional_packages="htop nvtop tmux ripgrep fd-find"
additional_packages="nodejs npm"

# --- INIT HOOKS (Build Time) ---
# 1. Install 'uv'
init_hooks="curl -LsSf [https://astral.sh/uv/install.sh](https://astral.sh/uv/install.sh) | sh"
# 2. Install Gemini CLI
init_hooks="sudo npm install -g @google/gemini-cli"
# 3. Install Conductor Extension
init_hooks="gemini extensions install [https://github.com/gemini-cli-extensions/conductor](https://github.com/gemini-cli-extensions/conductor) --auto-update"
# 4. Install Python 3.12 (via uv to local bin)
init_hooks="$HOME/.local/bin/uv python install 3.12"

# --- ENTRY HOOKS (Run Time) ---
entry_hooks="export UV_VENV_IN_PROJECT=1"
# Note: Gemini login is handled via browser on first run; token persists in ~/.config

5. Recovery Procedures
Scenario A: "I broke Python / The Lab is corrupted."

Severity: Low | Time: < 2 Minutes

If you install a bad package or break your Python environment inside the sar-lab container:

    Nuke it:
    Bash

    distrobox stop sar-lab
    distrobox rm sar-lab

    Edit Config (Optional): If the break was caused by a bad init hook, edit the definition:
    Bash

    hx ~/Projects/nanshan-infra/distrobox.ini

    Rebuild it:
    Bash

    cd ~/Projects/nanshan-infra
    distrobox assemble create --file distrobox.ini

    Resume: Enter the lab (distrobox enter sar-lab). Your project files in ~/1_Projects are untouched.

Scenario B: "I broke the Host OS / Pop!_OS won't boot."

Severity: Critical | Time: ~20 Minutes

If an update breaks the OS or you lose access to the system:

    Reinstall OS:

        Boot from Pop!_OS USB.

        Select "Clean Install" on the 2TB NVMe.

    Restore Config:

        Clone your config repo (or copy from backup): git clone <your-repo-url> ~/Projects/nanshan-infra

    Run Host Provisioning:
    Bash

    cd ~/Projects/nanshan-infra
    chmod +x setup_nanshan.sh
    ./setup_nanshan.sh

    Reboot: Restart to finalize user groups.

    Rebuild Lab: Run the distrobox assemble command from Scenario A.

    Mount Data: Remount the 4TB ZFS array to ~/3_Resources/Datasets.
