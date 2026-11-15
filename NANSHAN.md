# NANSHAN WORKSTATION CONFIGURATION
**Status:** Active | **Role:** Deep Learning & SAR Operations | **Owner:** Jason

## 1. Hardware Specifications
* **Model:** Lenovo ThinkStation P620
* **CPU:** AMD Threadripper Pro 5965WX (24 Cores / 48 Threads)
* **RAM:** 64GB DDR4-3200 ECC (4x 16GB)
* **GPU:** NVIDIA GeForce RTX 3060 (12GB VRAM)
* **Storage (Tier 1 - OS/Hot):** 2TB NVMe SSD (Pop!_OS root + home)
* **(Planned) Storage (Tier 2 - OS):** 1TB NVMe SSD for Pop!_OS root; home stays on the 2TB NVMe
* **Storage (Tier 3 - Data):** 2x 4TB Seagate Enterprise HDD (ST4000NM0035), ZFS mirror `vault` at `/mnt/vault`
* **Networking:** Aquantia 10GbE + Intel Wi-Fi 6

---

## 2. Operational Philosophy
Nanshan follows an **"Atomic" Infrastructure-as-Code** philosophy. The goal is to keep the Host OS distinct from the Development Environment to ensure stability and rapid recovery.

### The Three Layers
1.  **Layer 0: Host OS (Pop!_OS)**
    * **Role:** Bare metal driver management (NVIDIA, Network), Container Runtime, Encryption, ZFS storage, NFS, remote access.
    * **State:** *Immutable-ish.* We rarely install software here via `apt`.
    * **Tools:** `git`, `podman` + `distrobox`, Tailscale, `uv`, `ruff`, `basedpyright`, `helix`, `chezmoi`, `starship`, `zoxide`, `fzf`, `atuin`, Gemini CLI.
2.  **Layer 1: GUI Applications (Flatpak)**
    * **Role:** User-facing tools (Browsers, IDEs, Chat).
    * **Isolation:** Sandboxed from the OS. Updated independently.
    * **Apps:** Zen Browser, Zed IDE, Obsidian, Discord, QGIS.
3.  **Layer 2: The Labs (Distrobox)**
    * **State:** *Ephemeral.* Created and destroyed via `distrobox.ini`. `$HOME` is shared with the host, so code and tools in `~/.local/bin` / `~/.npm-global` survive a rebuild.
    * **`sar-lab`:** The actual workspace. Ubuntu 24.04 + NVIDIA, Python 3.12 via `uv`, GDAL/NetCDF/HDF5, QGIS + PyQt5 for Spyglass plugin development, OpenGL/Xvfb for Gymnasium/MuJoCo rendering. Mounts `/mnt/vault/sar_data` at the same path.
    * **`ai-lab`:** Ubuntu 24.04 + NVIDIA for local LLMs (Ollama). Models live in `~/.ollama` on the NVMe.

---

## 3. Directory Structure (PARA)
Filesystem layout optimized for context separation.

```text
/home/jaynbrown/
├── Projects/            # Active Code (Git Repos)
│   ├── nanshan-infra/   # THIS REPO (Provisioning scripts)
│   └── marlow/          # DRL Agent (+ frontend/spyglass QGIS plugin)
├── Areas/               # Ongoing Responsibility (Admin, Docs)
├── Resources/           # Static Assets
│   ├── docs/
│   └── papers/
└── Archives/            # Cold Storage

/mnt/vault/              # ZFS mirror (HDD)
├── sar_data/            # SAR datasets (mounted into sar-lab)
└── homelab_backups/     # NFS target for Proxmox Backup Server (2T quota)
```

Dotfiles (`.bashrc`, Helix, Starship, git config, ZFS scrub units) live in a separate chezmoi repo: `github.com/jaynbrown/dotfiles` (`~/.local/share/chezmoi`).

---

## 4. Provisioning
The scripts are the source of truth; this section only summarises them. See [README.md](README.md) for step-by-step install order.

### A. Host (`setup_nanshan.sh`)
Run after a fresh Pop!_OS install. Re-running it is supported, but note that it runs `apt upgrade` and `chezmoi apply --force` (commit any local dotfile edits first).

1. APT base packages, OpenSSH, ufw firewall (SSH allowed only from 192.168.100.0/24, 192.168.1.0/24 and Tailscale).
2. Tailscale (`tailscale up` opens a browser login).
3. Node.js 20, user-space npm prefix, Gemini CLI + Conductor extension.
4. `uv`, `ruff`, `basedpyright`.
5. chezmoi (clones and applies the dotfiles repo).
6. zoxide, fzf, atuin, bash-preexec, Starship.
7. Helix (static binary, pinned by `HELIX_VER`) into `~/.local/bin`.
8. Flatpak GUI apps.
9. Git identity.
10. **Storage:** ZFS + NFS packages, 4GB ARC limit, `vault` pool (imported if it already exists, created only on blank disks), datasets, NFS export, scrub timer, sanoid snapshots. See section 5.

### B. Labs (`distrobox.ini`)
```bash
cd ~/Projects/nanshan-infra
distrobox assemble create --file distrobox.ini
```
Then inside `sar-lab`, run `./setup_lab.sh`, a health check that verifies the shared Gemini CLI and `uv`, installs Python 3.12, and installs Starship if missing.

---

## 5. Storage: the `vault` Pool
* **Layout:** ZFS mirror of the two 4TB HDDs (by-id paths in `setup_nanshan.sh`), `ashift=12`, `compression=lz4`, ARC capped at 4GB.
* **`vault/sar_data`:** Owned by `jaynbrown`, bind-mounted into `sar-lab`.
* **`vault/homelab_backups`:** NFS export for Proxmox Backup Server on **suhaili (192.168.1.3)** only. Options `rw,sync,all_squash,anonuid=34,anongid=34`, so every client user (root included) writes as PBS's `backup` user. Managed in `/etc/exports.d/homelab_backups.exports`; ufw allows TCP 2049 from that host only, so clients must mount with NFSv4.
* **Scrubs:** `zfs-scrub-vault.timer` (from chezmoi), first Sunday of each month at 04:00.
* **Snapshots (sanoid, every 15 min):**
  * `sar_data`: 24 hourly, 30 daily, 6 monthly.
  * `homelab_backups`: 7 daily (snapshot space counts toward the 2T quota).
  * Recover files from `/mnt/vault/<dataset>/.zfs/snapshot/`.

### Known gaps
* **No alerting:** ZED is not configured, so scrub errors or a degraded mirror are silent. Check `zpool status vault` periodically.
* **No off-machine copy:** mirror + snapshots do not survive theft, fire, or a host compromise.

---

## 6. Recovery Procedures

### Scenario A: "I broke Python / The Lab is corrupted."
**Severity:** Low | **Time:** < 2 Minutes

1. **Nuke it:**
   ```bash
   distrobox stop sar-lab
   distrobox rm sar-lab
   ```
2. **Edit config (optional):** if a bad hook caused the break, fix `~/Projects/nanshan-infra/distrobox.ini`.
3. **Rebuild just that lab:**
   ```bash
   cd ~/Projects/nanshan-infra
   distrobox assemble create --file distrobox.ini --name sar-lab
   ```
4. **Resume:** `distrobox enter sar-lab`. Your files in `~/Projects` live in the shared home and are untouched.

### Scenario B: "I broke the Host OS / Pop!_OS won't boot."
**Severity:** Critical | **Time:** ~20 Minutes

1. **Reinstall OS:** boot the Pop!_OS USB and choose "Clean Install" on the **2TB NVMe only**. Do not touch the two 4TB HDDs.
2. **Restore SSH key** from Bitwarden (see README step 1).
3. **Clone this repo:** `git clone git@github.com:jaynbrown/nanshan-infra.git ~/Projects/nanshan-infra`
4. **Run host provisioning:**
   ```bash
   cd ~/Projects/nanshan-infra
   ./setup_nanshan.sh
   ```
   The script detects the existing `vault` pool and **imports** it (data preserved); it never re-creates a pool it finds. Manual equivalent, which does not modify data:
   ```bash
   sudo zpool import -d /dev/disk/by-id -f vault
   ```
   **Never** run `zpool create` on the vault disks; that erases the mirror.
5. **Reboot** to finalize user groups.
6. **Rebuild labs:** run the `distrobox assemble` command from section 4B.
