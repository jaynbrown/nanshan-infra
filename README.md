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

Run the host setup script to install system tools, GUI apps, and configure the environment:

```bash
chmod +x setup_nanshan.sh
./setup_nanshan.sh
```

**Note:** This script will prompt for your sudo password and may require a reboot upon completion.

### 4. SAR Lab Setup (Container)

The development environment runs inside a Distrobox container to keep the host clean.

1.  **Create the container:**
    ```bash
    distrobox assemble create --file distrobox.ini
    ```
2.  **Enter the container:**
    ```bash
    distrobox enter sar-lab
    ```
3.  **Finalize Lab setup (Inside Container):**
    ```bash
    cd ~/Projects/nanshan-infra
    chmod +x setup_lab.sh
    ./setup_lab.sh
    source ~/.bashrc
    ```

## 📂 Repository Structure

- `setup_nanshan.sh`: Host OS provisioning script.
- `distrobox.ini`: Definition for the `sar-lab` development container.
- `setup_lab.sh`: Post-creation script for the `sar-lab` container.
- `NANSHAN.md`: Detailed hardware specs and operational philosophy.
- `GEMINI.md`: Context for the Gemini CLI agent.

## 🛠 Maintenance

- **Update Host:** Run `setup_nanshan.sh` again or use `chezmoi update`.
- **Nuke & Rebuild Lab:**
  ```bash
  distrobox rm -f sar-lab
  distrobox assemble create --file distrobox.ini
  ```
