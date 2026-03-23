# CloudWS — Cloud Workstation OS

**Self-replicating, immutable, cloud-native workstation OS built on Fedora Rawhide bootc.**

GNOME 50 • Flatpak-first • KVM/QEMU/VFIO Passthrough • Podman/K3s • Pacemaker HA • Waydroid • CrowdSec

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

## Architecture

```
Fedora Rawhide fc45 | Kernel 7.0 | GNOME 50 | Wayland-only
├── ComposeFS + XFS (bare-metal) / ext4 (images)
├── bootc (immutable, atomic upgrades, rollback)
├── Flatpak-first (5 baked apps, GNOME Software for more)
├── KVM/QEMU/Libvirt + VFIO GPU Passthrough + Looking Glass
├── Podman + K3s + Pacemaker/Corosync HA Clustering
├── Waydroid (Android — native Wayland windows)
├── Multi-GPU (Mesa + NVIDIA akmod + driverctl VFIO)
├── CrowdSec IPS + fapolicyd + USBGuard + firewalld
├── cloud-init (autonomous deployment anywhere)
└── Self-replication (cloudws-rebuild → push → pull → update)
```

## Desktop

**RPM layer:** GNOME Shell, Nautilus, Ptyxis, GNOME Software, System Monitor, Disk Utility, virt-manager

**Baked Flatpaks:** Epiphany (browser), Baobab (disk usage), Podman Desktop, Bottles (Wine), VSCodium

**Extensions:** Dash to Dock, AppIndicator, Tiling Assistant

All theming follows GNOME Settings (dark/light) dynamically via xdg-desktop-portal. No hardcoded themes.

## Self-Update

```bash
sudo bootc update        # Pull latest
sudo bootc rollback      # Revert
cloudws-rebuild          # Rebuild from embedded sources
```

## Security

| Layer | Technology |
|-------|-----------|
| Immutable root | composefs + fs-verity |
| Execution block | fapolicyd (blocks untrusted /var/home binaries) |
| USB protection | USBGuard |
| Network IPS | CrowdSec (collaborative IP banning) |
| Firewall | firewalld default-deny drop zone |
| App sandbox | Flatpak + Bubblewrap |
| AV scan | `scan-malware` (containerized ClamAV) |
| VM isolation | SELinux sVirt |
| Encryption | LUKS2 (optional, prompted at build) |
| Boot trust | TPM2 + Secure Boot compatible |

## Legal

CloudWS assembles open-source and select proprietary components under their respective licenses:

- **Fedora Rawhide:** Various (MIT, GPL, LGPL, BSD) — [Fedora Legal](https://docs.fedoraproject.org/en-US/legal/)
- **RPMFusion:** Various — [RPMFusion FAQ](https://rpmfusion.org/FAQ)
- **NVIDIA drivers:** Proprietary (RPMFusion nonfree, user-accepted)
- **Steam:** Proprietary (Valve Corporation, user-accepted SSA)
- **CrowdSec:** MIT | **K3s:** Apache-2.0 | **Looking Glass:** GPL-2.0
- **Flatpak apps:** Per-app (GNOME: GPL, Bottles: GPL-3.0, VSCodium: MIT, Podman Desktop: Apache-2.0)

Build scripts: **MIT License**. Users are responsible for license compliance when redistributing.

Trademarks (GNOME, Fedora, NVIDIA, Steam, etc.) belong to their respective owners. CloudWS is not affiliated with or endorsed by these organizations.

---

**Maintainer:** [@Kabuki94](https://github.com/Kabuki94)
