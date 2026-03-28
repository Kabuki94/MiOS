# CloudWS — Cloud Workstation OS

**Self-replicating, immutable, cloud-native workstation OS built on Fedora Rawhide bootc.**

GNOME 50 • Gamescope Steam Session • KVM/QEMU/VFIO • Podman/K3s • Pacemaker HA • CrowdSec (Sovereign)

---

## Default Credentials

| | |
|---|---|
| **Username** | `cloudws` |
| **Password** | `cloudws` |

Pre-built images from GHCR use these defaults. Custom builds prompt for credentials (press Enter to accept defaults).

---

## Quick Start

### Windows (PowerShell as Administrator)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.sh | bash
```

### Direct bare-metal install (from any Linux live USB)

```bash
sudo podman run --rm -it --privileged --pid=host \
  ghcr.io/kabuki94/cloudws-bootc:latest \
  bootc install to-disk /dev/sdX
```

---

## Prerequisites

Run the preflight checker to auto-install missing requirements:

```powershell
irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/preflight.ps1 | iex
```

| Windows | Linux |
|---------|-------|
| Windows 10/11 Pro+ | podman or docker |
| WSL2 (`wsl --install`) | git |
| Podman Desktop | Root access (for bare-metal) |
| Git | |
| Hyper-V (optional) | |

## What Gets Built

| Target | Description |
|--------|-------------|
| OCI Image | Compressed container (~8-12GB on registry) |
| RAW Disk | Bootable disk image (auto-sized) |
| VHDX | Dynamic Hyper-V disk |
| WSL Tarball | WSL2 + WSLg import |
| Anaconda ISO | Installer for bare-metal |
| Live USB ISO | Bootable live environment |
| GHCR | `ghcr.io/kabuki94/cloudws-bootc` (auto-update) |

## Architecture

```
Fedora Rawhide fc45 | Kernel 7.0 | GNOME 50 "Tokyo" | Wayland-only
├── ComposeFS + XFS (bare-metal) / ext4 (images)
├── bootc (immutable, atomic upgrades, rollback)
├── Flatpak-first (5 pre-installed apps, user-removable + GNOME Software for more)
├── Gamescope Steam Session (SteamOS-mode, selectable at GDM)
├── KVM/QEMU/Libvirt + VFIO GPU Passthrough + Looking Glass B7
├── Podman + K3s + Pacemaker/Corosync HA Clustering
├── Waydroid (Android — GAPPS pre-configured, native Wayland windows)
├── Multi-GPU (Mesa + NVIDIA akmod + driverctl VFIO toggle)
├── GPU Auto-Detect (blocks NVIDIA in VMs, enables virtual GPU — boots everywhere)
├── CrowdSec IPS (sovereign/offline — zero outbound telemetry)
├── fapolicyd + USBGuard + firewalld (default-deny drop zone)
├── cloud-init (autonomous deployment anywhere)
└── Self-replication (cloudws-rebuild → clone → build → push)
```

## Desktop

**GDM Sessions:**
- **GNOME (Wayland)** — Full desktop environment
- **Steam (Gamescope)** — Fullscreen SteamOS-mode gaming session

**RPM layer:** GNOME Shell, Nautilus, Ptyxis, GNOME Software, System Monitor, Disk Utility, virt-manager

**Pre-installed Flatpaks:** Epiphany (browser), Logs, Podman Desktop, Bottles, Extension Manager, VSCodium

**Extensions:** Dash to Dock, AppIndicator, Tiling Assistant, Caffeine (managed via Extension Manager Flatpak)

## Self-Update

```bash
cloudws-update                 # One-command update from GHCR (recommended)
sudo bootc update              # Pull latest from GHCR directly
sudo bootc rollback            # Revert to previous deployment
cloudws-rebuild                # Clone from GitHub → build → push
cloudws-backup                 # Backup volumes, K3s, VMs, home
cloudws-vfio-toggle list       # Show GPUs + IOMMU groups
```

> **Important:** The GHCR package must be set to **public** for `bootc update` to work without authentication.
> The build script attempts to do this automatically via the GitHub API. If it fails, manually set visibility at:
> `https://github.com/Kabuki94?tab=packages` → Package Settings → Change Visibility → **Public**

## WSL2

```powershell
# Deploy
wsl --import CloudWS $env:USERPROFILE\WSL\CloudWS cloudws-wsl.tar --version 2

# Backup
wsl --export CloudWS C:\Backups\cloudws-backup.tar
```

**WSL2 limitations:** GUI apps require WSLg (Windows 11 22H2+). GDM, Waydroid, and firewalld are automatically masked in WSL. Some apps may need `source /etc/profile.d/cloudws-wsl.sh` in your shell for proper Wayland/X11 display setup.

## Security

| Layer | Technology |
|-------|-----------|
| Immutable root | composefs + fs-verity |
| Execution block | fapolicyd (blocks untrusted /var/home binaries) |
| USB protection | USBGuard |
| Network IPS | CrowdSec (sovereign — no outbound telemetry) |
| Firewall | firewalld default-deny drop zone |
| App sandbox | Flatpak + Bubblewrap |
| AV scan | `scan-malware` (containerized ClamAV) |
| VM isolation | SELinux sVirt (build-time context enforcement) |
| Encryption | LUKS2 (optional, prompted at install) |
| Boot trust | TPM2 + Secure Boot compatible |

## Repo Structure

```
CloudWS-bootc/
├── cloud-ws.ps1      # Main build script (Windows, builds all targets)
├── install.ps1       # Windows one-line bootstrap
├── install.sh        # Linux one-line installer
├── preflight.ps1     # Windows prerequisite checker
├── push-to-github.ps1# Push all files to GitHub
├── PACKAGES.md       # Complete package inventory
├── README.md         # This file
├── .gitignore        # Excludes build output
└── LICENSE           # MIT
```

## Legal

CloudWS assembles open-source and select proprietary components under their respective licenses:

- **Fedora Rawhide:** Various (MIT, GPL, LGPL, BSD) — [Fedora Legal](https://docs.fedoraproject.org/en-US/legal/)
- **RPMFusion:** Various — [RPMFusion FAQ](https://rpmfusion.org/FAQ)
- **NVIDIA drivers:** Proprietary (RPMFusion nonfree, user-accepted)
- **Steam:** Proprietary (Valve Corporation, user-accepted SSA)
- **CrowdSec:** MIT | **K3s:** Apache-2.0 | **Looking Glass:** GPL-2.0
- **Flatpak apps:** Per-app (GNOME: GPL, Bottles: GPL-3.0, Podman Desktop: Apache-2.0)

Build scripts: **MIT License**. Users are responsible for license compliance when redistributing.

Trademarks (GNOME, Fedora, NVIDIA, Steam, etc.) belong to their respective owners. CloudWS is not affiliated with or endorsed by these organizations.

---

**Maintainer:** [@Kabuki94](https://github.com/Kabuki94)
