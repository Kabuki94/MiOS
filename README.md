# CloudWS — Cloud Workstation OS

**Self-replicating, immutable, cloud-native workstation OS built on bootc.**

> Version **v1.3.0** · [ghcr.io/kabuki94/cloudws-bootc:latest](https://ghcr.io/kabuki94/cloudws-bootc)

GNOME 50 • Gamescope Steam Session • KVM/QEMU/VFIO • Podman/K3s • Pacemaker HA • CrowdSec (Sovereign)

Fully portable — supports **AMD, Intel, and NVIDIA** CPUs and GPUs out of the box. GPU auto-detection at boot adjusts for bare metal, Hyper-V, QEMU, or VMware. One image runs everywhere: bare metal, Hyper-V, QEMU/KVM, VMware, WSL2, and OCI containers.

---

## What's New in v1.3.0 (The Standardized Stack)

The **v1.3.0** release represents a major architectural synchronization across the entire stack:

*   **WSL2-Native Graphical Support**: Automated `wsl.conf` initialization during build. GNOME/Wayland applications now work out-of-the-box in WSL2 without manual configuration.
*   **Pathing Standardization**: Aligned with Fedora CoreOS/bootc standards by symlinking `/home` to `/var/home`. This ensures all standard Linux tools and user creation scripts work seamlessly within the immutable filesystem.
*   **DNF5 Prioritized Pipeline**: Accelerated package management by prioritizing `dnf5` in all build scripts, ensuring faster image assembly and future-proof dependency resolution.
*   **LBI Stability**: Restored and stabilized Logically Bound Image (LBI) support. The `postgres:15` container (for Guacamole) is now pre-pulled during build to ensure `bootc-image-builder` succeeds during disk generation.
*   **Unified Versioning**: All components—from script headers to container labels—are now strictly aligned to the **v1.3.0** baseline.

---

## Variants

| Variant | Base Image | Use Case |
|---------|-----------|----------|
| **CloudWS-1** | `quay.io/fedora/fedora-bootc:rawhide` | Fedora Rawhide with akmod-built GPU drivers |
| **CloudWS-2** | `ghcr.io/ublue-os/ucore-hci:stable-nvidia` | Pre-signed NVIDIA modules via Universal Blue MOK |

Both variants produce identical output formats and share the same build scripts, package manifest, and system overlays.

---

## Self-Building Architecture

CloudWS is its own build environment **and** its own image builder. Each published image ships every tool needed to produce the next version — including `osbuild`, `image-builder`, `qemu-img`, `openssl`, and all disk-image generation dependencies. There is no separate "builder" image. The **only** images CloudWS ever pulls are the base images it builds on top of (`fedora-bootc:rawhide` or `ucore-hci:stable-nvidia`).

When you run a build, the orchestrator:
1. Pulls the previously published `ghcr.io/kabuki94/cloudws-bootc:latest`
2. Uses it as the helper container for **all** build-time operations — credential hashing, OCI build support, `qemu-img` VHDX conversion, and disk image generation (RAW, ISO, VHDX, WSL)
3. Builds the next CloudWS image on top of the base image
4. The result is a new CloudWS image that can build the version after it

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
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1'))
```

```powershell
$tmp = "$env:TEMP\cloudws-install.ps1"; irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | Set-Content $tmp; & $tmp; Remove-Item $tmp
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

## Build System

### Build Workflows

| Workflow | Description |
|----------|-------------|
| **Local Build Only** | Build the OCI image and generate deployment targets locally |
| **Build + Push** | Full pipeline — build, generate targets, push to GHCR |
| **Custom Build** | Specify custom username, password, hostname, registry, and token |
| **Pull + Deploy Only** | Pull an existing image from GHCR and generate deployment targets |

### Build Pipeline

1. **Phase 0** — Configuration prompts (username, password, LUKS, registry, **self-build mode**)
2. **Phase 1** — Dedicated Podman builder machine init/start
3. **Phase 1.5** — Pull previous CloudWS image (self-building helper + image builder)
4. **Phase 2** — `podman build --no-cache` with credential injection → rechunk
5. **Phase 3** — Disk image generation: RAW, VHDX, WSL, ISO (self-build uses CloudWS; first-build uses centos-bootc BIB)
6. **Phase 4** — Push to GHCR with `--password-stdin`
7. **Phase 5** — Cleanup, restore default machine, build report

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Base OS | Fedora Rawhide bootc (fc45) / ucore-hci, ComposeFS, dnf5, systemd, SELinux |
| Desktop | GNOME 50 (Wayland-only), Mutter, GTK 4, libadwaita, Geist font, Bibata cursor |
| Virtualization | KVM / QEMU / libvirt, VFIO GPU passthrough, Looking Glass B7, swtpm |
| Containers | Podman, Buildah, Skopeo, bootc, K3s |
| Image Building | osbuild, image-builder, bootc-base-imagectl, qemu-img |
| Gaming | Steam, Gamescope SteamOS session, Wine, Lutris, Bottles, MangoHud |
| HA Clustering | Pacemaker, Corosync, PCS, keepalived, haproxy, etcd |
| Security | CrowdSec (sovereign/offline), USBGuard, firewalld |
| GPU | Mesa (AMD/Intel), NVIDIA akmod or pre-signed modules, ROCm, driverctl |
| Android | Waydroid with GAPPS |
| Storage | CephFS / cephadm, NFS, GlusterFS, iSCSI, Stratis, LVM |

---

## Design Principles

- **Immutable**: Read-only root (ComposeFS). Mutable state in `/var` and `/etc`.
- **Self-replicating**: CloudWS builds CloudWS. The image IS the build environment AND the image builder.
- **Single-image stack**: Only images are CloudWS (helper) + upstream base. No Alpine, no centos-bootc BIB (after bootstrap).
- **Declarative**: Everything defined in version-controlled source.
- **Universal**: Boots on bare metal, Hyper-V, QEMU, VMware, WSL2. GPU auto-detect adapts at boot.
- **Atomic updates**: OTA from GHCR via `bootc upgrade`. Rollback via `bootc rollback`.
- **Zero post-install pulls**: Everything baked at build time.

---

## Documentation

All long-form docs live under [`docs/`](docs/). Top-level policy files (changelog, security, licensing, contributing) remain at the repo root.

### Repository root

| Document | Description |
|----------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history in Keep a Changelog format |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute — conventions, build process, PR requirements |
| [SECURITY.md](SECURITY.md) | Security hardening checklist: kernel params, sysctls, SELinux policy |
| [LICENSES.md](LICENSES.md) | Component licenses, including proprietary (NVIDIA, Steam) acceptance notes |

### User & operator guides (`docs/`)

| Document | Description |
|----------|-------------|
| [docs/UPGRADE.md](docs/UPGRADE.md) | How to upgrade, rollback, and switch between versions |
| [docs/HARDWARE.md](docs/HARDWARE.md) | GPU/CPU/platform compatibility matrix with driver details |
| [docs/SELF-BUILD.md](docs/SELF-BUILD.md) | Self-build mode guide — bootstrapping, CI, and local builds |
| [docs/DIAGNOSTICS.md](docs/DIAGNOSTICS.md) | Where to find logs, diagnostic commands, and how to collect a support bundle |
| [docs/BACKUP.md](docs/BACKUP.md) | Backup and restore strategy for `/var`, `/home`, VMs, and containers |
| [docs/gpu-passthrough.md](docs/gpu-passthrough.md) | Universal VFIO GPU passthrough plumbing and runtime selection |

### Package manifest & audits (`docs/`)

| Document | Description |
|----------|-------------|
| [docs/PACKAGES.md](docs/PACKAGES.md) | **Single source of truth for every RPM installed.** Parsed at build time by `scripts/lib/packages.sh` from fenced ` ```packages-<category> ` blocks. |
| [docs/PACKAGES-AUDIT.md](docs/PACKAGES-AUDIT.md) | Audit of suggested packages vs. what's already in `PACKAGES.md` |

### CI / infrastructure (`docs/`)

| Document | Description |
|----------|-------------|
| [docs/CI_RUNNERS.md](docs/CI_RUNNERS.md) | GitHub Actions self-hosted runner setup |
| [docs/RUNNER_REQS.md](docs/RUNNER_REQS.md) | Runner hardware and software requirements |
| [docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md) | Open research questions and investigation plan |

### Historical changelogs (`docs/changelogs/`)

Per-release changelogs prior to the consolidated root `CHANGELOG.md` live in [`docs/changelogs/`](docs/changelogs/) — one file per version (`CHANGELOG-v1_3_0.md` through `CHANGELOG-v2_2_7.md`).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

### v1.3.0 (current)

- **GNOME Remote Desktop for Hyper-V Enhanced Session** — xRDP deprecated (Mutter 50 dropped X11); RDP now delivered via `grdctl --system rdp` + vsock. First-boot TLS cert generation via `/usr/libexec/cloudws-grd-setup`.
- **FreeIPA enrollment consolidation** — single path through `22-freeipa-client.sh` + `cloudws-freeipa-enroll.service`. Removed the parallel `50-freeipa-client.sh` / `cloudws-ipa-enroll.service` stack that referenced a non-existent service.
- **WSL2 gating consolidated in `20-services.sh`** — `WSL_SKIP_SERVICES` is the single source of truth for skip drop-ins; `18-apply-boot-fixes.sh` and `38-vm-gating.sh` no longer duplicate them.
- **Logically Bound Images** — every Quadlet `.container` shipped via the overlay is symlinked into `/usr/lib/bootc/bound-images.d/` at build time, so `bootc upgrade` pre-fetches them.
- **Renovate digest pinning for `ARG BASE_IMAGE`** — `customManager` regex rotates the `@sha256:...` suffix on the Containerfile ARG line (the `dockerfile` manager only pins bare `FROM` lines).
- **CI build fix** — Containerfile `ARG BASE_IMAGE` default is tag-only until Renovate pins it; previously the unresolved `REPLACE_WITH_CURRENT_DIGEST` placeholder broke every default-path build.
- **cloudws-init ordering** — now `After=network-online.target cloud-final.service ignition-firstboot-complete.service` so DHCP/NM settle before group/firewall setup runs.
- **DHCP client-ID = MAC** — NetworkManager drop-in prevents IP conflicts in cloned VMs where `/etc/machine-id` is duplicated.
- **dbus-daemon-wsl.service** — adds `Alias=dbus.service` so WSL2 boots without a D-Bus deadlock even when preset-all misses the unit.

### v0.1.3

- **Fully self-contained build stack** — CloudWS ships `osbuild`, `image-builder`, `qemu-img`, and all disk-image generation deps. Self-build mode eliminates all external tool containers.
- **Self-build question** — Phase 0 now asks whether to use CloudWS as its own BIB. First builds default OFF (centos-bootc BIB). After first push, all subsequent builds can be fully self-contained.
- **CloudWS-2 variant** — Added `ucore-hci:stable-nvidia` base with pre-signed NVIDIA modules.
- **Version unification** — Single `VERSION` file drives all version strings.
- **PACKAGES.md** — Added `image-builder`, `osbuild-selinux`, `dracut-live`, `squashfs-tools` to packages-containers.

### v0.1.2

- Phase 1.5 self-building cycle — pulls previous CloudWS from GHCR as build helper.

### v0.1.1

- Initial public installer (`install.ps1` one-liner). Preflight checker. Four build workflows.

### v0.1.0

- Initial release. Fedora Rawhide bootc, GNOME 50, full virt stack, Gamescope session.
- Five output formats. 14 custom CLI tools, GPU auto-detect, SELinux hardening.

---

## Legal

CloudWS assembles open-source and select proprietary components under their respective licenses:

- **Fedora Rawhide:** Various (MIT, GPL, LGPL, BSD)
- **RPMFusion:** Various
- **NVIDIA drivers:** Proprietary (RPMFusion nonfree, user-accepted)
- **Steam:** Proprietary (Valve Corporation, user-accepted SSA)
- **CrowdSec:** MIT | **K3s:** Apache-2.0 | **Looking Glass:** GPL-2.0

Build scripts and CloudWS tooling: **MIT License**

---

Built by [Kabu](https://github.com/Kabuki94) · [ghcr.io/kabuki94/cloudws-bootc](https://ghcr.io/kabuki94/cloudws-bootc)
