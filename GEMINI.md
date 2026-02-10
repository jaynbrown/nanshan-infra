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

*   **`NANSHAN.md`**: The primary documentation file detailing hardware specifications, operational philosophy (Host OS, GUI Apps, SAR Lab layers), directory structure, provisioning scripts, and recovery procedures for the Nanshan Workstation.
*   **`distrobox.ini`**: A configuration file for `distrobox` that defines the `sar-lab` container. It specifies the base image (`ubuntu:24.04`), enables NVIDIA support, and lists system dependencies and entry hooks for configuring the container's environment.
*   **`setup_nanshan.sh`**: This script is responsible for provisioning the *host* Pop!_OS system. It handles system updates, installs essential tools (e.g., git, distrobox, podman, SSH, Tailscale), sets up Node.js, Gemini CLI (for the host), `uv` and Python tools (ruff, basedpyright), Chezmoi (dotfile manager), Zoxide, FZF, Atuin, Starship, Helix editor, and Flatpak applications. It also configures global Git settings.
*   **`setup_lab.sh`**: This script is designed to be executed *inside* the `sar-lab` Distrobox container. It further configures the development environment by upgrading Node.js, installing `uv` (Python manager), configuring NPM for user-space package installation, installing the Gemini CLI and its Conductor extension, installing Python 3.12 via `uv`, and setting up Starship.

## Usage

The general workflow for setting up and maintaining the Nanshan Workstation using this repository is as follows:

1.  **Host Provisioning:**
    *   After a fresh Pop!_OS install, run `setup_nanshan.sh` on the host machine.
    *   `cd ~/Projects/nanshan-infra` (assuming this repo is cloned here).
    *   `chmod +x setup_nanshan.sh`
    *   `./setup_nanshan.sh`
    *   Reboot the host system as instructed by the script.

2.  **SAR Lab Setup (Distrobox Container):**
    *   Ensure Distrobox is installed (handled by `setup_nanshan.sh`).
    *   From the host machine, navigate to this repository: `cd ~/Projects/nanshan-infra`.
    *   Create the `sar-lab` container using the `distrobox.ini` configuration:
        `distrobox assemble create --file distrobox.ini`
    *   Enter the newly created `sar-lab` container: `distrobox enter sar-lab`.
    *   Inside the `sar-lab` container, run `setup_lab.sh` to finalize its configuration:
        `cd ~/Projects/nanshan-infra` (or wherever the repo is mounted inside the container).
        `chmod +x setup_lab.sh`
        `./setup_lab.sh`
    *   Source the `.bashrc` inside the container: `source ~/.bashrc`.

3.  **Recovery Procedures:**
    *   **Corrupted Lab:** If the `sar-lab` Distrobox container becomes corrupted, it can be nuked and rebuilt using the commands described in `NANSHAN.md` under "Scenario A."
    *   **Corrupted Host OS:** If the host Pop!_OS breaks, a clean reinstall, cloning this repository, and re-running `setup_nanshan.sh` will restore the system, as detailed in `NANSHAN.md` under "Scenario B."
