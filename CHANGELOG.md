# Changelog

All notable changes to CloudWS-bootc are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions CI/CD pipeline (build → rechunk → cosign sign → GHCR push)
- SBOM generation (SPDX + CycloneDX) via syft, attached to each build
- Cosign keyless image signing via Fulcio/Rekor OIDC
- Weekly GHCR cleanup of untagged images (keep 7 most recent)
- `CONTRIBUTING.md` with project conventions and submission workflow
- `docs/UPGRADE.md` with step-by-step upgrade, rollback, and troubleshooting
- `docs/SECURITY.md` with complete hardening checklist and override instructions
- `docs/HARDWARE.md` with GPU/CPU/platform support matrix
- `docs/DIAGNOSTICS.md` with logging, journal, and diagnostic bundle guide
- `docs/BACKUP.md` with backup/restore strategy for `/var` and `/home`
- GitHub issue templates (bug report, feature request, security)
- Pull request template with CloudWS-specific checklist

## [2.1.0] — 2026-04-12

Codename: **Ecosystem Intelligence Update**

### Breaking Changes
- `lockdown=confidentiality` kernel boot param prevents unsigned module loading
- `kernel.io_uring_disabled=2` blocks io_uring syscalls
- `kernel.kexec_load_disabled=1` prevents runtime kernel replacement

### Added
- 6 new SecureBlue kernel hardening parameters (15 total)
- 4 new sysctl hardening entries
- NVIDIA CDI as default mode (nvidia-container-toolkit v1.19+)
- `nvidia-cdi-refresh.service` for auto CDI spec regeneration
- `bootupd.service` for unified bootloader updates
- `podman-restart.service` for quadlet container restart policy
- 3 new SELinux policies (cloudws_cdi, cloudws_quadlet, cloudws_sysext)
- `image-versions.yml` for SHA256 digest pinning (Renovate target)
- `renovate.json` for automated dependency management
- `bootupd` and `dnf5-plugins` packages for boot/update management

### Changed
- systemd-boot-unsigned added for bootupd integration
- WSL2 service gating expanded (nvidia-cdi-refresh, bootupd)
- Post-build validation now checks bootupd and CVE status

### Security
- CDI fcontext for NVIDIA device specs
- Spectre v2/v4, L1TF, and GDS/Downfall mitigations enforced

## [2.0.0] — 2026-04-10

Codename: **ucore Rebasing**

### Breaking Changes
- Base image changed to `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (CloudWS-2)
- `install_weak_deps=False` enforced globally (was True in v1.3 — contradicted docs)

### Changed
- NVIDIA modules from ucore pre-signed base (no akmod build needed, Secure Boot works)
- Safe arithmetic: `VAR=$((VAR + 1))` everywhere (never `((VAR++))`)
- Post-build validates malcontent-libs present (flatpak dependency)
- gnome-software KEPT (manages Flatpaks on immutable systems)
- PackageKit/gnome-tour removed via dnf (safe, no cascade)
- malcontent-control hidden via NoDisplay (dnf remove cascades gnome-shell)

## [1.3.0] — 2026-04-06

Codename: **Intelligence Update**

### Breaking Changes
- systemd 260: cgroup v1 support REMOVED — all services must use cgroup v2
- systemd 260: SysV service scripts no longer supported
- GNOME 49+: systemd is a HARD dependency
- Kernel 7.0: kernel-modules-core split from kernel-modules
- NVIDIA 590: Pascal (GTX 10xx) support dropped

### Added
- dnf5 cache mount for 5-10x faster rebuilds
- `/opt → /var/opt` symlink (Universal Blue pattern)
- `/usr/lib/bootc/kargs.d/00-cloudws.toml` declarative kernel boot arguments
- `/usr/lib/ostree/prepare-root.conf` composefs verified boot
- `/usr/lib/sysctl.d/99-cloudws-hardening.conf` SecureBlue-style hardening
- Repo priority hierarchy: CrowdSec(80) < Terra(85) < RPMFusion(90) < Fedora(99)
- Post-build package validation (14 critical packages, footgun check)
- RTX 50-series VFIO reset bug detection and warning
- NVIDIA open kernel modules default for Turing+
- `cloudws-vfio-check` tool
- Looking Glass B7 with libdecor + PipeWire support
- K3s pinned to v1.32.3+k3s1 with SELinux enforcement
- CrowdSec dashboard quadlet example
- `podman-auto-update.timer` for quadlet auto-updates
- `bootloader-update.service` for bootc systems

### Fixed
- pmcd/pmlogger services no longer enabled (only pmproxy is installed)
- Duplicate pcp entries in PACKAGES.md
- Removed Arch-only packages (lib32-gamemode, libstrangle)

### Security
- SELinux policy: cloudws_portabled (systemd-portabled D-Bus)
- SELinux policy: cloudws_kvmfr (Looking Glass shared memory)
- 9 kernel hardening boot parameters via kargs.d
- Kernel sysctl hardening profile (26 parameters)

## [1.2.0] — 2026-03-20

### Added
- Bibata-Modern-Classic cursor theme (OS-wide including GDM and XWayland)
- tuned daemon with throughput-performance profile
- fastfetch in `/etc/skel/.bashrc`
- Waydroid GAPPS oneshot service with OTA URLs
- VSCodium replaced with page.tesk.Refine (Flatpak ID change)

### Fixed
- `/etc/skel/.bashrc` ordering: written before `useradd -m`
- Flatpak font rendering via filesystem overrides
- SELinux: container_use_cephfs, virt_use_samba booleans
- SELinux: user_home_dir_t fcontext for `/var/home`
- K3s deduplication: removed duplicate block from 12-virt.sh
- ucore-hci: steam-devices vs udev-joystick-blacklist-rm file conflict
- ucore-hci: `cp -a` failure on `/usr/local` symlink
- ucore-hci: missing initramfs (dracut step added)

## [1.1.0] — 2026-03-01

### Added
- CloudWS-2 variant on ucore-hci:stable-nvidia base
- Hyper-V Enhanced Session support via xRDP vsock
- cloud-init integration for dynamic provisioning
- authselect local profile (zero extra features)

### Fixed
- GTK_THEME=Adwaita-dark replaced with ADW_DEBUG_COLOR_SCHEME=prefer-dark
- SELinux monolithic module split into per-rule individual modules
- WSL2 UTF-16 handling for `wsl --list --quiet`
- BIB config: TOML only (cannot receive both config.json and config.toml)

## [1.0.0] — 2026-02-15

### Added
- Initial release
- Two-stage Containerfile (FROM scratch AS ctx + Fedora Rawhide bootc)
- PACKAGES.md single source of truth (~240 RPMs, 5 Flatpaks)
- 9 numbered build scripts (01-repos through 99-overrides)
- 19 system_files overlays
- cloud-ws.ps1 Windows orchestrator (5-phase build pipeline)
- Justfile Linux build targets
- 5 deployment formats: RAW, VHDX, WSL2, ISO, OCI push
- GPU auto-detection at boot
- GNOME 50 Wayland-only desktop
- Full KVM/QEMU/VFIO stack with Looking Glass
- Podman/K3s container runtime
- Pacemaker/Corosync HA clustering
- CrowdSec sovereign-mode IPS
- Gamescope SteamOS GDM session
- Waydroid Android with GAPPS
- 14 custom cloudws-* CLI tools

[Unreleased]: https://github.com/Kabuki94/CloudWS-bootc/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/Kabuki94/CloudWS-bootc/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/Kabuki94/CloudWS-bootc/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/Kabuki94/CloudWS-bootc/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Kabuki94/CloudWS-bootc/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Kabuki94/CloudWS-bootc/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Kabuki94/CloudWS-bootc/releases/tag/v1.0.0
