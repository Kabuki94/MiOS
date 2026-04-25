# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# Changelog
All notable changes to this project will be documented in this file.

## [v2.1.0] - 2026-04-25

### 🛠️ Hardware & WSL2 Optimization
* **Intel Battlemage Support:** Implemented strict `xe` driver bindings for Xe2 hardware.
* **WSL2 Stability:** Resolved `dbus-broker` crashes on WSL2 kernels.
* **RTX 50 VFIO fix:** Initial Blackwell GSP firmware workaround deployed.

## [v2.1.0] - 2026-04-22

### ⚙️ Core OS & Role Engine Consolidation
* **Unified Role Engine:** Consolidated the asynchronous initialization and role management into the extensionless `system_files/usr/libexec/mios/role-apply` script.
* **Formal Role Targets:** Introduced `mios-{desktop,headless,k3s-master,ha-node}.target` for strict role isolation.
* **Architectural Overlay Purity:** Consolidated all dynamically created systemd units into the `system_files/` overlay. Removed redundant root-level config directories.
* **Next-Gen MOTD:** Enhanced `/usr/libexec/mios/motd` with live Role, MOK (Secure Boot), and Update status indicators.
* **2026 Flatpak Standard:** Adopted `/usr/share/flatpak/pre-installed.d/` for mandatory application delivery.
* **Logging Purity:** Audited and fixed malformed UTF-8/encoding issues in all shell scripts.

### 🏗️ Build & CI/CD Optimization
* **Rechunking Fix:** Optimized the CI pipeline to generate 5-10x smaller updates by running rechunking inside a privileged container.
* **Docs Restructure Fix:** Resolved build failures caused by the relocation of `PACKAGES.md` to `docs/PACKAGES.md`.
* **Build Diagnostics:** Enhanced `packages.sh` with FATAL error logging for mandatory sections.
* **Fix (Virtualization):** Removed `dkms` from `packages-looking-glass-build` manifest to resolve `kernel-devel-matched` dependency conflict on mixed kernel builds.
* **Fix (Scripts):** Hardened `12-virt.sh` to ensure `/usr/share/mios/virtio` exists before VirtIO-Win ISO download.

## [v2.1.0] - 2026-04-18

### 🛠️ Hardware & GPU Passthrough
* **NVIDIA 595+ Stability:** Injected `NVreg_UseKernelSuspendNotifiers=1` to fix Wayland freezes on Ada/Blackwell hardware.
* **WSL v2.1.0 Fix:** Gated `systemd-networkd-wait-online.service` on `!wsl` to prevent session timeouts.
* **WSL v2.1.0 Fix:** Enforced 0755 on `wsl-user-generator` to fix login failures.
* **Blackwell Safety Fix:** Implemented `vfio_pci.disable_idle_d3=1` workaround in `kargs.d`.

## [v2.1.0] - 2026-04-16

### ⚙️ Driver & Hardware Optimization
* **NVIDIA Open Modules:** Standardized on NVIDIA open kernel modules as the default for Turing+.
* **CDI Generation:** Integrated build-time CDI specification generation for NVIDIA GPUs.

## [v2.1.0] - 2026-04-14

### 🖥️ Desktop & UI Evolution
* **GNOME 50 Transition:** Migrated to GNOME 50 (Wayland-only). Removed all legacy X11 session components.
* **DNF5 Build Shift:** Fully transitioned the build pipeline to `dnf5`.

## [v2.1.0] - 2026-03-25

### 🚀 Unified Image Architecture
* **Role-at-Boot:** Introduced the `mios-role.service` and `role.conf` system.
* **ublue-os Adoption:** Integrated pre-signed NVIDIA kmods and adopted the `uupd` unified updater.
* **Image Signing:** Implemented `cosign` keyless signing via GitHub Actions.

## [v2.1.0] - 2026-03-12

### 🔒 Ecosystem Intelligence & Hardening
* **SecureBlue Integration:** Deployed SecureBlue-inspired kernel and sysctl hardening.
* **Bootloader Management:** Added `bootupd` for unified bootloader updates.

## [v2.1.0] - 2026-02-15

### ⚙️ Core OS Foundation
* **systemd 260 Compliance:** Removed cgroup v1 support and SysV compatibility.
* **composefs Integration:** Promoted root filesystem to `enabled = yes`.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
