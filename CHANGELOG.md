# Changelog
All notable changes to this project will be documented in this file.

## [v2.3.5] - 2026-04-20

### ⚙️ Core OS & Role Engine Consolidation
* **Unified Role Engine:** Consolidated the asynchronous initialization and role management into the extensionless `system_files/usr/libexec/cloudws/role-apply` script. This unified engine now handles system-wide init (Phase 1), Blackwell hardware safety (Phase 2), and non-blocking service transitions (Phase 4).
* **Redundancy Cleanup:** Deleted the legacy `role-apply.sh` script to maintain architectural purity.
* **Docs Restructure Fix:** Resolved build context failures caused by the relocation of `PACKAGES.md` to `docs/PACKAGES.md`. The `Containerfile` now correctly maps the path during the context stage.

### 🏗️ Build & Overlay
* **Overlay Stability:** Fixed a critical failure during the `/usr/local` symlink creation on ucore/bootc bases (v2.3.3 legacy fix).
* **Passthrough Plumbing:** Staged all passthrough-related overlay directories (`systemd/`, `udev/`, `tmpfiles.d/`, `sysusers.d/`, `kargs.d/`) into the build context for reliable injection into the image.

## [v2.3.4] - 2026-04-18

### 🛠️ Hardware & GPU Passthrough
* **Umbrella Rename:** Renamed `cloudws-gpu-detect.service` to `cloudws-gpu-status.service` to prevent name collisions with the hardware-renderer detection service.
* **Blackwell Safety Fix:** Superseded the `v2.2.8` fix for Blackwell (RTX 50) VFIO reset cycles with a more robust `vfio_pci.disable_idle_d3=1` implementation in `kargs.d`.

## [v2.3.2] - 2026-04-16

### ⚙️ Driver & Hardware Optimization
* **NVIDIA Open Modules:** Standardized on NVIDIA open kernel modules as the default for Turing+ and the exclusive option for Blackwell. Added `NVreg_OpenRmEnableUnsupportedGpus=1` to support older Pascal/Maxwell cards.
* **CDI Generation:** Integrated build-time CDI specification generation for NVIDIA GPUs, with a runtime refresh path for hotplug events.

## [v2.3.0] - 2026-04-14

### 🖥️ Desktop & UI Evolution
* **GNOME 50 Transition:** Migrated to GNOME 50 (Wayland-only). Removed all legacy X11 session components in accordance with Fedora 43+ upstream changes.
* **DNF5 Build Shift:** Fully transitioned the build pipeline to `dnf5` for improved performance and reliable transaction handling.

## [v2.2.7] - 2026-04-10

### 🐚 Scripting & Compatibility
* **IRM Compatibility:** Rewrote `install.ps1` and `preflight.ps1` using ASCII-only decorations to ensure compatibility with `irm | iex` consumption paths, avoiding UTF-8 BOM decoding errors.

## [v2.2.4] - 2026-04-05

### 🏗️ Single Source of Truth Enforcement
* **Package Manifest Consolidation:** Enforced `docs/PACKAGES.md` as the absolute single source of truth. All provisioning scripts (41-47) were stripped of inline `dnf install` calls, delegating all installations to the `packages.sh` parser.
* **Redundant Logic Removal:** Deleted `scripts/51-install-unified-packages.sh` and consolidated its logic into the core numbered pipeline.

## [v2.2.0] - 2026-03-25

### 🚀 Unified Image Architecture
* **Role-at-Boot:** Introduced the `cloudws-role.service` and `role.conf` system, allowing a single OCI image to transform into any role (desktop, k3s, HA, headless) at boot time.
* **ublue-os Adoption:** Integrated pre-signed NVIDIA kmods from the Universal Blue ecosystem and adopted the `uupd` unified updater.
* **Image Signing:** Implemented `cosign` keyless signing via GitHub Actions with SLSA provenance attestations.

## [v2.1.0] - 2026-03-12

### 🔒 Ecosystem Intelligence & Hardening
* **SecureBlue Integration:** Deployed 15 kernel hardening parameters and 4 critical sysctl hardening settings based on the SecureBlue audit.
* **Bootloader Management:** Added `bootupd` for unified bootloader updates (Fedora 44 Phase 1).

## [v1.3.0] - 2026-02-15

### ⚙️ Core OS Foundation
* **systemd 260 Compliance:** Removed cgroup v1 support and SysV service script compatibility.
* **composefs Integration:** Promoted root filesystem to `enabled = yes` with dedup support via `prepare-root.conf`.

## [v0.1.1] - 2026-01-20

### 🛠️ Hardware & WSL2 Optimization
* **Intel Battlemage Support:** Implemented strict `xe` driver bindings for Xe2 hardware.
* **WSL2 Stability:** Resolved `dbus-broker` crashes on WSL2 kernels by injecting strict hypervisor gating.
* **RTX 50 VFIO fix:** Initial Blackwell GSP firmware workaround deployed.
