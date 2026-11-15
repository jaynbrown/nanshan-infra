# Gemini CLI Context for Nanshan Workstation Configuration

This `GEMINI.md` file provides essential context for the Gemini CLI when interacting with the `nanshan-infra` repository.

## Directory Overview

This repository (`nanshan-infra`) serves as the configuration management and provisioning toolkit for the "Nanshan Workstation," a dedicated machine for Deep Learning and Synthetic Aperture Radar (SAR) operations. It embodies an "Atomic Infrastructure-as-Code" philosophy, aiming to keep the Host OS distinct from the development environment for stability and rapid recovery.

The repository primarily contains:
*   **Documentation:** Explaining the workstation's setup, philosophy, and recovery procedures.
*   **Host Provisioning Script:** To set up the base Pop!_OS system.
*   **Distrobox Configuration:** To define and provision the "SAR Lab" development container.
*   **Lab Setup Script:** To finalize the development environment within the Distrobox container.

## Key Files

*   **`NANSHAN.md`**: The primary documentation: hardware, operational philosophy (Host OS, Flatpak apps, Distrobox labs), directory layout, provisioning summary, ZFS `vault` storage, and recovery procedures.
*   **`README.md`**: Step-by-step reinstall order (SSH key from Bitwarden, clone, host provisioning, lab setup).
*   **`setup_nanshan.sh`**: Provisions the *host* Pop!_OS system: APT tools, SSH + ufw, Tailscale, Node.js 20 + Gemini CLI, `uv`/ruff/basedpyright, chezmoi dotfiles, zoxide/fzf/atuin/Starship, Helix, Flatpak apps, git identity, and storage (ZFS `vault` mirror, NFS export for Proxmox Backup Server, scrub timer, sanoid snapshots).
*   **`distrobox.ini`**: Defines the `sar-lab` (Ubuntu 24.04 + NVIDIA, geospatial/QGIS/rendering packages, vault mount) and `ai-lab` (Ollama) containers.
*   **`setup_lab.sh`**: A health check run *inside* `sar-lab`. It verifies the Gemini CLI and `uv` shared from the host via `$HOME`, installs Python 3.12 via `uv`, and installs Starship if missing.
*   **`distrobox_ai.ini`**: Legacy and superseded by `distrobox.ini`; do not use.

## Important Constraints

*   **Never run `zpool create` on the vault disks.** After an OS reinstall the pool must be imported (`setup_nanshan.sh` does this automatically).
*   Dotfiles are managed in a separate chezmoi repo (`jaynbrown/dotfiles`); edit them there, not in `~`.
*   The scripts are the source of truth. Docs summarise them and should not embed copies.

## Usage

Follow `README.md` for install order and `NANSHAN.md` section 6 for recovery (Scenario A: rebuild a lab; Scenario B: reinstall the host).
