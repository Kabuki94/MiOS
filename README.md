# CloudWS — Cloud Workstation OS

**Self-replicating, immutable, cloud-native workstation OS built on bootc.**

> Version **v0.1.3** · [ghcr.io/kabuki94/cloudws-bootc:latest](https://ghcr.io/kabuki94/cloudws-bootc)

GNOME 50 • Gamescope Steam Session • KVM/QEMU/VFIO • Podman/K3s • Pacemaker HA • CrowdSec (Sovereign)

Fully portable — supports **AMD, Intel, and NVIDIA** CPUs and GPUs out of the box. GPU auto-detection at boot adjusts for bare metal, Hyper-V, QEMU, or VMware. One image runs everywhere: bare metal, Hyper-V, QEMU/KVM, VMware, WSL2, and OCI containers.

---

## Variants

| Variant | Base Image | Use Case |
|---------|-----------|----------|
| **CloudWS-1** | `quay.io/fedora/fedora-bootc:rawhide` | Fedora Rawhide with akmod-built GPU drivers |
| **CloudWS-2** | `ghcr.io/ublue-os/ucore-hci:stable-nvidia` | Pre-signed NVIDIA modules via Universal Blue MOK |

Both variants produce identical output formats and share the same build scripts, package manifest, and system overlays.

---

## Self-Building Architecture

CloudWS is its own build environment. Each published image contains every tool needed to produce the next version — there is no separate "builder" image. When you run a build, the orchestrator pulls the previously published `ghcr.io/kabuki94/cloudws-bootc:latest` and uses it as the helper container for all build-time operations (hashing, `qemu-img` conversion, `openssl`, etc.). The only external dependency is `centos-bootc` BIB (bootc-image-builder) for disk image generation.

```
┌─────────────────────────────────────────────────────┐
│  CloudWS v(N) image (from GHCR)                    │
│  ├── provides: openssl, qemu-img, coreutils, etc.  │
│  └── used as helper for all build operations        │
│                                                     │
│  Containerfile + scripts/ + PACKAGES.md             │
│  └── podman build → CloudWS v(N+1) image           │
│                                                     │
│  centos-bootc BIB (external)                        │
│  └── converts OCI → RAW, VHDX, ISO, WSL            │
└─────────────────────────────────────────────────────┘
```

---

## Default Credentials

| | |
|---|---|
| **Username** | `cloudws` |
| **Password** | `cloudws` |

Pre-built images from the registry use these defaults. Custom builds prompt for credentials (press Enter to accept defaults within 30 seconds).

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

### Hyper-V Gen2 VM

Build or download the VHDX, create a Gen2 VM, then **before first boot**:

1. **Secure Boot** → Change template to **Microsoft UEFI Certificate Authority** (NOT "Microsoft Windows")
2. **Dynamic Memory** → Disable entirely, or set minimum RAM ≥ 4096 MB
3. Attach the VHDX as the boot disk

### WSL2

```powershell
wsl --import CloudWS $env:USERPROFILE\WSL\CloudWS cloudws-wsl.tar --version 2
```

GUI apps require WSLg (Windows 11 22H2+). GDM, Waydroid, and firewalld are automatically masked in WSL2.

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

---

## What Gets Built

| Target | Description |
|--------|-------------|
| OCI Image | Compressed container (~8-12GB on registry), rechunked for optimal Day-2 updates |
| RAW Disk | Bootable disk image (80 GiB root, optional LUKS2 encryption) |
| VHDX | Dynamic Hyper-V Gen2 disk (BIB VHD → qemu-img VHDX conversion) |
| WSL Tarball | WSL2 + WSLg import (`wsl --import`) |
| Anaconda ISO | Installer for bare-metal (Rufus/Ventoy USB write) |
| Registry Push | GHCR (`ghcr.io/kabuki94/cloudws-bootc:latest`), auto-update via `bootc upgrade` |

After building, OCI layers are optimized via `bootc-base-imagectl rechunk` for 5-10x smaller Day-2 updates.

---

## Architecture

```
Fedora Rawhide (fc45) | GNOME 50 "Tokyo" | Wayland-only
├── ComposeFS + XFS (bare-metal) / ext4 (images)
├── bootc (immutable, atomic upgrades, rollback)
├── Flatpak-first (6 pre-installed apps, user-removable + GNOME Software)
├── Gamescope Steam Session (SteamOS-mode, selectable at GDM)
├── KVM/QEMU/Libvirt + VFIO GPU Passthrough + Looking Glass B7
├── Podman + K3s + Pacemaker/Corosync HA Clustering
├── Waydroid (Android — GAPPS pre-configured, native Wayland windows)
├── Multi-GPU (Mesa + NVIDIA akmod + driverctl VFIO toggle)
├── GPU Auto-Detect (blocks NVIDIA in VMs, forces Cairo renderer — boots everywhere)
├── CrowdSec IPS (sovereign/offline — zero outbound telemetry)
├── fapolicyd + USBGuard + firewalld (default-deny drop zone)
├── Cockpit Web Management (https://localhost:9090)
├── PCP Metrics History (pmcd + pmlogger + pmproxy for Cockpit graphs)
├── cloud-init (autonomous deployment anywhere)
├── authselect local profile (PAM configured for reliable password auth)
└── Self-replication (cloudws-rebuild → clone → build → push)
```

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Base OS | Fedora Rawhide bootc (fc45) / ucore-hci, ComposeFS, dnf5, systemd, SELinux |
| Desktop | GNOME 50 (Wayland-only), Mutter, GTK 4, libadwaita, Geist font, Bibata cursor |
| Virtualization | KVM / QEMU / libvirt, VFIO GPU passthrough, Looking Glass B7, swtpm |
| Containers | Podman, Buildah, Skopeo, bootc, K3s |
| Gaming | Steam, Gamescope SteamOS session, Wine, Lutris, Bottles, MangoHud |
| HA Clustering | Pacemaker, Corosync, PCS, keepalived, haproxy, etcd |
| Security | CrowdSec (sovereign/offline), fapolicyd, USBGuard, firewalld |
| GPU | Mesa (AMD/Intel), NVIDIA akmod or pre-signed modules, ROCm, driverctl |
| Android | Waydroid with GAPPS |
| Storage | CephFS / cephadm (planned), NFS, GlusterFS, iSCSI, Stratis, LVM |
| Registry | GHCR (`ghcr.io/kabuki94/cloudws-bootc:latest`) |

---

## Desktop

**GDM Sessions:**

- **GNOME (Wayland)** — Full desktop environment with dark mode, Geist font, Bibata cursor
- **Steam (Gamescope)** — Fullscreen SteamOS-mode gaming session

**RPM layer:** GNOME Shell, Nautilus, Ptyxis (terminal), GNOME Software, virt-manager, Wine, Steam, Waydroid

**Pre-installed Flatpaks (exactly 6):**

| Flatpak | Description |
|---------|-------------|
| Epiphany | GNOME Web browser — also handles documents, photos, media natively |
| Logs | systemd journal viewer |
| Extension Manager | GNOME Shell extension manager |
| Podman Desktop | Container management GUI |
| VSCodium | Code editor |
| Refine | Modern interface tweaker (replaces gnome-tweaks) |

Bottles is installed on first login via a self-deleting autostart entry (from Flathub Beta).

**GNOME Extensions:** Dash to Dock (bottom, 48px), AppIndicator

**App Folders (dconf):** All installed apps are organized into 5 folders — Development, Gaming, System, Virtualization, Wine. No loose apps in the grid.

---

## Terminal

CloudWS opens a terminal with `fastfetch` system overview by default. Disable with `export CLOUDWS_NO_FASTFETCH=1`.

```bash
cloudws --help                 # Quick reference for all CloudWS commands
cloudws-update                 # One-command update from registry
cloudws-rebuild                # Clone from GitHub → build → push
cloudws-build                  # Build CloudWS locally (Linux-native)
cloudws-backup                 # Backup volumes, K3s, VMs, /var/home
cloudws-deploy <vm|container>  # Deploy VM or container from image
cloudws-vfio-toggle list       # Show GPUs + IOMMU groups
cloudws-hostname [name]        # Show/set cluster hostname
iommu-groups                   # Visualize IOMMU group assignments
scan-malware                   # On-demand containerized ClamAV scan
sudo bootc status              # Current deployment info
sudo bootc rollback            # Revert to previous deployment
sudo bootc upgrade             # Pull latest from registry
```

---

## Cockpit Web Dashboard

Accessible at **https://localhost:9090** after login. Cockpit is pinned to the dock and included in the System app folder.

**Installed Cockpit modules:** System, Storage, Networking, Podman Containers, Virtual Machines, Software Updates, SELinux, Image Builder (osbuild), PCP Metrics

**PCP (Performance Co-Pilot):** `pmcd`, `pmlogger`, and `pmproxy` are all installed and enabled. Cockpit uses these for metrics history graphs on the Overview page.

**Firewall:** The cockpit service is pre-opened in the firewalld drop zone. No manual firewall configuration needed.

---

## Build System

### Build Workflows

| Workflow | Description |
|----------|-------------|
| **Local Build Only** | Build the OCI image and generate deployment targets locally |
| **Build + Push** | Full pipeline — build, generate targets, push to GHCR |
| **Custom Build** | Specify custom username, password, hostname, registry, and token |
| **Pull + Deploy Only** | Pull an existing image from GHCR and generate deployment targets |

### Build Configuration

The build script asks configuration questions before building (30-second timeout per question, then defaults apply):

| Question | Default | Notes |
|----------|---------|-------|
| Username | `cloudws` | System login user |
| Password | `cloudws` | GDM + SSH + sudo password |
| LUKS Encryption | No | Applies to RAW and ISO targets |
| Registry URL | `ghcr.io/kabuki94/cloudws-bootc` | Where to push the OCI image |
| Registry credentials | From `$env:CLOUDWS_GHCR_USER` / `$env:CLOUDWS_GHCR_TOKEN` | PAT scope: `repo + write:packages` |

The build pulls the **previously published CloudWS image** from GHCR as its helper container — CloudWS builds itself. A dedicated `cloudws-builder` Podman machine (250 GB disk) is created for the build — your existing default Podman machine is never touched.

### Build Pipeline

1. **Phase 0** — Configuration prompts (username, password, LUKS, registry)
2. **Phase 1** — Dedicated Podman builder machine init/start
3. **Phase 1.5** — Pull previous CloudWS image as self-building helper
4. **Phase 2** — `podman build --no-cache` with credential injection → rechunk
5. **Phase 3** — BIB generates RAW, VHDX, WSL, ISO targets (80 GiB root via bib.json)
6. **Phase 4** — Push to GHCR with `--password-stdin` (token never in CLI args)
7. **Phase 5** — Cleanup, restore default machine, build report

### How the OCI Build Works

1. **Stage 1** (`FROM scratch AS ctx`): Copies `scripts/`, `PACKAGES.md`, `VERSION`, and `system_files/` into a scratch layer for bind-mounting.

2. **Stage 2** (`FROM <base-image>`): A single `RUN` directive bind-mounts the context read-only, copies files to a writable `/tmp/build`, strips Windows line endings, runs `build.sh` (which executes each numbered script in glob order), then cleans up. A second `RUN` overlays `system_files/` into the root filesystem and runs `dconf update`. The image is labeled for bootc and validated with `bootc container lint`.

3. **Credential injection**: The orchestrator replaces `INJ_U` / `INJ_P` placeholders in `99-overrides.sh` with a pre-hashed password before building, then immediately restores the placeholders via `git checkout`. Plaintext credentials never appear in the build log.

4. **Rechunking**: After build, `bootc-base-imagectl rechunk` optimizes OCI layers for 5–10× smaller day-2 OTA deltas.

### Linux-Native Builds

Use the `Justfile` for builds on Linux:

```bash
just build          # podman build
just rechunk        # optimize OCI layers
just raw            # BIB → RAW disk image
just iso            # BIB → Anaconda ISO
just vhd            # BIB → VHD
just wsl            # podman export → WSL tarball
just push           # push to GHCR
just all            # build + rechunk + all targets + push
just switch         # fix deployed system's update origin
```

---

## Repository Structure

```
CloudWS-bootc/
├── Containerfile               # Two-stage OCI build (scratch context + bootc base)
├── cloud-ws.ps1                # Windows build orchestrator (PowerShell)
├── Justfile                    # Linux build targets
├── PACKAGES.md                 # Single source of truth — all packages (~240 RPMs, 6 Flatpaks)
├── VERSION                     # 0.1.3
├── README.md                   # This file
├── config/
│   ├── bib.json                # BIB: 80 GiB minimum root
│   └── bib.toml                # BIB: 80 GiB minimum root (TOML)
├── scripts/
│   ├── build.sh                # Master runner — executes numbered scripts, times each
│   ├── lib/packages.sh         # Parser — extracts packages from PACKAGES.md fenced blocks
│   ├── 01-repos.sh             # RPMFusion Free+Nonfree from Rawhide URLs
│   ├── 02-kernel.sh            # Kernel + headers (for akmod-nvidia)
│   ├── 10-gnome.sh             # GNOME 50, Geist font, Bibata cursor, 6 Flatpaks
│   ├── 11-hardware.sh          # Mesa + ROCm + NVIDIA akmod + CDI
│   ├── 12-virt.sh              # KVM, Podman, Cockpit, CrowdSec, Gaming, K3s, Looking Glass
│   ├── 20-services.sh          # systemd enables + bare-metal-only drop-ins
│   └── 99-overrides.sh         # PAM, user, firewall, GPU detect, 14 tools, SELinux, VM gating
├── system_files/               # Config overlays (19 files)
│   ├── etc/dconf/db/local.d/01-cloudws    # Dark mode, fonts, dock, app folders
│   ├── etc/environment.d/50-cloudws.conf  # Wayland/Qt/Electron env vars
│   ├── etc/gdm/custom.conf               # Wayland-only, auto-login disabled
│   ├── etc/modprobe.d/nvidia.conf         # modesetting, firmware, VRAM preserve
│   └── ...                                # sysctl, polkit, cockpit, waydroid, K3s, zram
├── install.ps1                 # Windows one-line bootstrap
├── install.sh                  # Linux one-line installer
├── preflight.ps1               # Windows prerequisite checker
└── push-to-github.ps1          # Flat-file organizer + repo publisher
```

---

## Package Manifest

All packages are declared in `PACKAGES.md` — the single source of truth. Build scripts parse fenced code blocks using `scripts/lib/packages.sh`. No package lists are duplicated across files.

**19 package categories:**

| Category | Packages | Key Components |
|----------|----------|----------------|
| Repos | 4 | RPMFusion Free/Nonfree, Workstation repos |
| Kernel | 10 | kernel, headers, devel (for akmod) |
| GNOME 50 | ~50 | Shell, Nautilus, Ptyxis, GDM, pipewire, Bluetooth, Software |
| GNOME Core Apps | ~25 | All commented out — uncomment to enable |
| GPU Mesa | 8 | Vulkan, DRI, VA-API, firmware, microcode |
| GPU AMD Compute | 2 | ROCm OpenCL/HIP |
| GPU NVIDIA | 3 | akmod-nvidia, CUDA, container toolkit |
| Virtualization | 10 | QEMU, libvirt, virt-manager, OVMF, swtpm |
| Containers | 16 | Podman, Buildah, Skopeo, bootc, osbuild, rpm-ostree |
| Cockpit | 14 | Full plugin set + PCP + pcp-system-tools |
| Windows Interop | 5 | xRDP, Samba, CIFS |
| Security | 8 | CrowdSec, fapolicyd, USBGuard, driverctl |
| Gaming | 14 | Steam, Wine, Gamescope, Lutris, DOSBox, Protontricks |
| Guest Agents | 6 | QEMU, Hyper-V, VMware, SPICE |
| Storage | 17 | NFS, GlusterFS, Ceph, iSCSI, Stratis, ZFS-ready |
| High Availability | 17 | Pacemaker, Corosync, PCS, fence agents, SBD |
| CLI Utilities | 22 | git, tmux, btop, nvtop, fastfetch, distrobox |
| Android | 1 | Waydroid |
| Looking Glass | 20 | Build deps (removed after compile) |

---

## Security

| Layer | Technology |
|-------|-----------|
| Immutable root | ComposeFS + fs-verity |
| Authentication | authselect local profile (pam_unix only, no SSSD) |
| Execution block | fapolicyd (blocks untrusted binaries) |
| USB protection | USBGuard |
| Network IPS | CrowdSec (sovereign mode — zero outbound telemetry) |
| Firewall | firewalld default-deny drop zone |
| App sandbox | Flatpak + Bubblewrap |
| AV scan | `scan-malware` (containerized ClamAV) |
| VM isolation | SELinux sVirt (build-time context enforcement) |
| Encryption | LUKS2 (optional, prompted at build time) |
| Boot trust | TPM2 + Secure Boot compatible |
| Custom SELinux | 5 per-rule policy modules for Rawhide-specific denials |

**Firewall zones:**

- **drop** (default): Allows cockpit, SSH, mDNS, RDP (3389/3390), Samba, NFS, libvirt (16509), VNC (5900-5999), K3s (6443, 10250), PCS (2224), Corosync (5403-5405/udp), iVentoy (26000)
- **trusted**: lo, podman0, virbr0, cni0, flannel.1, waydroid0, docker0 + K3s/Podman/libvirt subnets

---

## VM and Environment Detection

CloudWS uses `systemd-detect-virt` and `ConditionVirtualization=` drop-ins to automatically adapt to the deployment environment:

**Bare-metal-only services** (skipped silently in VMs via `ConditionVirtualization=no`):
nfs-server, smb, nmb, pacemaker, corosync, pcsd, crowdsec, crowdsec-firewall-bouncer, multipathd, osbuild-composer, osbuild-worker@1

**WSL2-only masking** (via `ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop`):
GDM, waydroid-container, dev-binderfs.mount

**All VMs** (via `ConditionVirtualization=no`):
nvidia-powerd

**GPU Auto-Detect** (`cloudws-gpu-detect.service` runs before GDM):

- VMs: NVIDIA modules blocked, GSK_RENDERER=cairo, GDK_DISABLE=vulkan, loads hyperv_drm/virtio-gpu/vmwgfx
- Bare metal: NVIDIA enabled, hardware renderer, no overrides

**serial-getty@ttyS0**: Masked (crash-loops in Hyper-V where no serial port exists)

---

## Updates

CloudWS uses bootc for atomic, image-based updates from the GHCR registry.

```bash
# Check for updates
sudo bootc upgrade

# Or use the CloudWS wrapper (with error handling and origin diagnostics)
cloudws-update

# Rollback to previous image
sudo bootc rollback
```

GNOME Software also shows OS updates via the rpm-ostree D-Bus bridge (`gnome-software-rpm-ostree` is pre-installed).

**Update origin:** The image is tagged with the GHCR ref (`ghcr.io/kabuki94/cloudws-bootc:latest`) **before** BIB runs, so all disk images have the correct update origin baked in.

**For already-deployed systems with wrong origin:**

```bash
sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest
sudo reboot
```

This preserves all state in `/etc` and `/var` (SSH keys, home directories, configs).

> **Important:** The GHCR package must be set to **public** for `bootc upgrade` to work without authentication. The build script attempts to do this automatically via the GitHub API. If it fails, manually set visibility at: `https://github.com/Kabuki94?tab=packages` → Package Settings → Change Visibility → **Public**

---

## Design Principles

- **Immutable**: The root filesystem is read-only (ComposeFS). All mutable state lives under `/var` and `/etc`.
- **Self-replicating**: CloudWS builds CloudWS. The published image is the build environment for the next version.
- **Declarative**: Every package, config file, and service is defined in version-controlled source. Nothing is installed interactively.
- **Universal**: One image boots on bare metal, Hyper-V, QEMU, VMware, and WSL2. GPU auto-detection at boot adapts drivers and services to the detected environment.
- **Atomic updates**: OTA updates pull the next image from GHCR. Rollback is one `bootc rollback` away.
- **Zero post-install pulls**: Everything is baked at build time — no runtime package fetching required.

---

## Network Boot (PXE)

CloudWS supports network deployment via Anaconda + Kickstart:

```kickstart
# cloudws-pxe.ks — PXE boot kickstart for CloudWS
text
network --bootproto=dhcp --device=link --activate
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs
ostreecontainer --url ghcr.io/kabuki94/cloudws-bootc:latest
user --name=cloudws --groups=wheel --plaintext --password=cloudws
reboot
```

PXE boot a standard Fedora Boot ISO, point it at this kickstart, and the installer pulls CloudWS from the registry. For air-gapped environments, use the Anaconda ISO target directly.

---

## Requirements

### Build Host

- **Windows**: Podman Desktop (with WSL2 backend), PowerShell 7+, 32 GB RAM recommended
- **Linux**: Podman (rootful), `just` (for Justfile), 32 GB RAM recommended
- **Registry**: GitHub PAT with `repo` + `write:packages` scope (for push workflow)

### Target Hardware

- **CPU**: Any x86_64 processor (AMD and Intel both supported)
- **GPU**: AMD (Mesa), Intel (Mesa), NVIDIA (akmod or pre-signed modules)
- **RAM**: 8 GB minimum, 16+ GB recommended
- **Disk**: 80 GiB minimum (set by BIB config)

---

## Troubleshooting

### Hyper-V VM won't boot / hangs at GRUB

- Ensure Secure Boot template is **Microsoft UEFI Certificate Authority** (NOT "Microsoft Windows")
- Disable Dynamic Memory or set minimum RAM ≥ 4096 MB
- Hyper-V host must be Server 2019+ (Server 2016 has UEFI firmware bugs)

### Cockpit shows "PCP is missing for metrics history"

The `pcp`, `pcp-system-tools`, and `cockpit-pcp` packages must all be installed. `pmcd`, `pmlogger`, and `pmproxy` services must be running. Check with:

```bash
systemctl status pmcd pmlogger pmproxy
```

### GNOME Software shows no OS updates / "chronologically older" error

The image origin may be pointing to `localhost` instead of GHCR. Fix with:

```bash
bootc status    # check the image reference
sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest
sudo reboot
```

### Apps are loose in the grid / not in folders

The dconf database must be compiled. On a deployed system:

```bash
sudo dconf update
```

Then log out and back in. App folders are defined in `/etc/dconf/db/local.d/01-cloudws`.

### SELinux denials (bootupctl, accounts-daemon, systemd-resolved)

CloudWS builds 5 individual SELinux policy modules at image time. If types are missing from the current Rawhide policy, that specific module fails but others succeed. Check with:

```bash
semodule -l | grep cloudws
```

### serial-getty@ttyS0 crash-looping

This is masked by default. If you see it in logs, verify:

```bash
systemctl status serial-getty@ttyS0    # should show "masked"
```

---

## Changelog

### v0.1.3

- **Self-building architecture** — CloudWS image is now the builder. No separate builder image required.
- **CloudWS-2 variant** — Added `ucore-hci:stable-nvidia` base with pre-signed NVIDIA modules.
- **Version unification** — Single `VERSION` file drives all version strings across install.ps1, cloud-ws.ps1, and build output.

### v0.1.2

- Phase 1.5 self-building cycle — pulls previous CloudWS from GHCR as build helper.
- BIB fallback to centos-bootc when CloudWS image lacks bootc-image-builder binary.

### v0.1.1

- Initial public installer (`install.ps1` one-liner).
- Preflight checker (`preflight.ps1`).
- Four build workflows (Local, Build+Push, Custom, Pull+Deploy).

### v0.1.0

- Initial release. Fedora Rawhide bootc base, GNOME 50, full virtualization stack, Gamescope session.
- Five output formats: RAW, VHDX, WSL, ISO, OCI push.
- 14 custom CLI tools, GPU auto-detect, SELinux hardening.

---

## Legal

CloudWS assembles open-source and select proprietary components under their respective licenses:

- **Fedora Rawhide:** Various (MIT, GPL, LGPL, BSD) — [Fedora Legal](https://docs.fedoraproject.org/en-US/legal/)
- **RPMFusion:** Various — [RPMFusion FAQ](https://rpmfusion.org/FAQ)
- **NVIDIA drivers:** Proprietary (RPMFusion nonfree, user-accepted)
- **Steam:** Proprietary (Valve Corporation, user-accepted SSA)
- **CrowdSec:** MIT | **K3s:** Apache-2.0 | **Looking Glass:** GPL-2.0
- **Flatpak apps:** Per-app (GNOME: GPL, Bottles: GPL-3.0, Podman Desktop: Apache-2.0)

Build scripts and CloudWS tooling: **MIT License**

---

Built by [Kabu](https://github.com/Kabuki94) · [ghcr.io/kabuki94/cloudws-bootc](https://ghcr.io/kabuki94/cloudws-bootc)
