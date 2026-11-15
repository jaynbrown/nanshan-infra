# Nanshan Workstation Infrastructure

This repository contains the configuration and provisioning scripts for the Nanshan Workstation, following an "Atomic" Infrastructure-as-Code philosophy.

## 🚀 Complete Reinstall & Recovery

Follow these steps to restore the workstation from a fresh Pop!_OS installation.

### 1. Restore SSH Keys (Bitwarden)

Before cloning private repositories, restore your SSH keys from Bitwarden:

1.  **Install Bitwarden CLI:**
    ```bash
    curl -L "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw.zip
    unzip bw.zip && chmod +x bw
    sudo mv bw /usr/local/bin/
    ```
2.  **Login & Unlock:**
    ```bash
    bw login
    export BW_SESSION=$(bw unlock --raw)
    ```
3.  **Retrieve SSH Key:**
    *   Find your SSH key item (e.g., named "Nanshan SSH Key"):
        ```bash
        bw list items --search "Nanshan SSH Key"
        ```
    *   Download or copy the private key to `~/.ssh/id_ed25519`:
        ```bash
        # Replace <ITEM_ID> with the actual ID from the previous step
        bw get item <ITEM_ID> | jq -r '.notes' > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ```
4.  **Add to Agent:**
    ```bash
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519
    ```

### 2. Clone Repository

Clone this infrastructure repository to your Projects folder:

```bash
mkdir -p ~/Projects
cd ~/Projects
git clone git@github.com:jaynbrown/nanshan-infra.git
cd nanshan-infra
```

### 3. Host Provisioning

Run the host setup script to install system tools, GUI apps, remote access, and storage:

```bash
chmod +x setup_nanshan.sh
./setup_nanshan.sh
```

**Notes:**
* It prompts for your sudo password, and `tailscale up` opens a browser login partway through.
* It sets up the ZFS `vault` pool on the two 4TB HDDs. If the pool already exists (e.g. after an OS reinstall) it is **imported, not re-created**, so data is preserved.
* It also configures the NFS backup export, the monthly scrub timer, and sanoid snapshots. See `NANSHAN.md` section 5.
* Reboot when it finishes.

### 4. SAR Lab Setup (Container)

The development environment runs inside a Distrobox container to keep the host clean.

1.  **Create the containers** (`sar-lab` and `ai-lab`):
    ```bash
    distrobox assemble create --file distrobox.ini
    ```
2.  **Enter the container:**
    ```bash
    distrobox enter sar-lab
    ```
3.  **Verify the Lab (Inside Container):** `setup_lab.sh` is a health check. It confirms the Gemini CLI and `uv` shared from the host, installs Python 3.12, and installs Starship if missing.
    ```bash
    cd ~/Projects/nanshan-infra
    chmod +x setup_lab.sh
    ./setup_lab.sh
    source ~/.bashrc
    ```

## 📂 Repository Structure

- `setup_nanshan.sh`: Host OS provisioning script (tools, apps, Tailscale, ZFS vault, NFS, snapshots).
- `distrobox.ini`: Definitions for the `sar-lab` (development) and `ai-lab` (local LLM) containers.
- `setup_lab.sh`: Health check run inside `sar-lab`.
- `NANSHAN.md`: Hardware specs, operational philosophy, storage layout, and recovery procedures.
- `GEMINI.md`: Context for the Gemini CLI agent.

Dotfiles live in a separate chezmoi repo (`jaynbrown/dotfiles`), which `setup_nanshan.sh` clones and applies.

## 🛠 Maintenance

- **Update dotfiles only:** `chezmoi update`.
- **Re-run host provisioning:** `./setup_nanshan.sh` is safe to re-run, but it runs `apt upgrade` and `chezmoi apply --force`. Commit any local dotfile edits to chezmoi first, or they will be overwritten.
- **Nuke & Rebuild Lab:**
  ```bash
  distrobox rm -f sar-lab
  distrobox assemble create --file distrobox.ini --name sar-lab
  ```
