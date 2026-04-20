# CloudWS v0.1.8 CHANGELOG

**Release Date:** April 12, 2026
**Codename:** Ecosystem Intelligence Update
**Sources:** bootc v1.15, Universal Blue (Bazzite April 2026), SecureBlue, Fedora 44 Beta,
RHEL Image Mode, TunaOS, Bluefin, bootc-image-builder, image-builder-cli

---

## Breaking Changes

- **Kernel lockdown**: `lockdown=confidentiality` added to boot args — prevents unsigned module loading, kexec, and raw I/O. Disable if you need runtime kernel debugging.
- **io_uring disabled**: `kernel.io_uring_disabled=2` blocks io_uring syscalls. Remove from sysctl if your workload requires io_uring.
- **kexec disabled**: `kernel.kexec_load_disabled=1` prevents runtime kernel replacement. This is a security hardening measure.

## Security Hardening (SecureBlue Audit)

### Kernel Boot Parameters (kargs.d/00-cloudws.toml)
- **Added**: `init_on_free=1` — zero memory on deallocation (complement to init_on_alloc)
- **Added**: `lockdown=confidentiality` — kernel lockdown mode
- **Added**: `spectre_v2=on` — Spectre v2 mitigation enforcement
- **Added**: `spec_store_bypass_disable=on` — Spectre v4 (SSB) mitigation
- **Added**: `l1tf=full,force` — L1 Terminal Fault mitigation
- **Added**: `gather_data_sampling=force` — GDS/Downfall mitigation
- Total: **15 kernel hardening parameters** (was 9 in v2.0)

### Sysctl Hardening (99-cloudws-hardening.conf)
- **Added**: `kernel.kexec_load_disabled=1` — prevent runtime kernel replacement
- **Added**: `kernel.io_uring_disabled=2` — disable io_uring (attack surface reduction)
- **Added**: `net.ipv4.conf.all.secure_redirects=0` — block ICMP secure redirects
- **Added**: `net.ipv4.conf.default.secure_redirects=0` — block ICMP secure redirects
- Note: `kernel.modules_disabled` intentionally NOT set (breaks NVIDIA/VFIO runtime loading)

## NVIDIA / GPU

- **CDI is now DEFAULT mode**: nvidia-container-toolkit v1.19+ uses Container Device Interface by default. GPU access is now `podman run --device nvidia.com/gpu=0`
- **CDI auto-refresh service**: `nvidia-cdi-refresh.service` regenerates CDI specs on driver reload and GPU hotplug
- **CVE check**: Build validation now warns if nvidia-container-toolkit < v1.17.7 (CVE-2025-23266 Critical, CVE-2025-23267 High)
- **RTX 50xx note**: Blackwell GPUs REQUIRE open kernel modules — proprietary modules are incompatible

## SELinux (3 New Policies)

- **`cloudws_cdi`**: NVIDIA CDI device access for container_t (enables `--device nvidia.com/gpu=0`)
- **`cloudws_quadlet`**: Podman quadlet container runtime directory watching
- **`cloudws_sysext`**: systemd-sysext overlay mount access into /usr
- **`/etc/cdi` fcontext**: Added container_file_t label for CDI spec directory
- Total: **16 custom SELinux policy modules** (was 13 in v2.0)

## Composefs & Boot

- **prepare-root.conf**: Added `[root]` section documentation for `transient-ro` (bootc v1.15+)
- **composefs**: Updated config to `enabled = yes` with documentation for `signed` mode
- **Logically-bound images**: Created `/usr/lib/bootc/bound-images.d/` directory for bootc v1.13+ workload binding

## Containerfile Improvements

- **OCI labels**: Added `org.opencontainers.image.*` and `io.artifacthub.*` labels for registry discoverability and cosign signing readiness
- **LABEL before CMD**: Fixed placement per OCI spec compliance
- **Post-build validation**: Now checks systemd unit enablement (not just package presence)
- **Footgun check**: Integrated directly into validation step (was separate)
- **restorecon scope**: Now covers `/usr/lib/bootc` and `/usr/lib/ostree` paths
- **bootupd**: Added to critical package validation list

## New Packages

| Package | Section | Purpose |
|---------|---------|---------|
| `bootupd` | boot | Unified bootloader updates (Fedora 44 phase 1) |
| `dnf5-plugins` | repos | versionlock support for critical package pinning |
| `systemd-boot-unsigned` | boot | UKI preparation for future composefs+UKI chain |
| `tpm2-tools` | security | TPM2 support for measured boot / attestation |
| `clevis` | security | Automated LUKS unlock via TPM2/Tang |
| `clevis-luks` | security | LUKS integration for Clevis |

## Build System

- **Rechunking**: Build summary now reminds to run `bootc-base-imagectl rechunk --max-layers 67` before push
- **Image size**: Build summary now estimates image size
- **Renovate Bot**: `renovate.json` config for automated base image digest updates
- **Image versions**: `image-versions.yml` for SHA256 digest pinning (Renovate target)

## Service Management (20-services.sh)

- **Added**: `bootupd.service` — unified bootloader updates
- **Added**: `nvidia-cdi-refresh.service` — CDI spec auto-refresh
- **Added**: `podman-restart.service` — restart policy for quadlet containers
- **WSL2 gating**: Added `nvidia-cdi-refresh` and `bootupd` to WSL skip list
- Version header bump to v2.1

## Files Changed (14 files)

| File | Status | Description |
|------|--------|-------------|
| VERSION | Modified | 2.0.0 → 2.1.0 |
| Containerfile | Modified | OCI labels, bound-images, validation, restorecon scope |
| PACKAGES.md | Modified | 6 new packages, new boot section, NVIDIA CDI notes |
| scripts/build.sh | Modified | bootupd validation, CVE check, rechunk reminder, image size |
| scripts/11-hardware.sh | Modified | CDI default, auto-refresh service, RTX 50 notes |
| scripts/20-services.sh | Modified | bootupd, CDI refresh, podman-restart, version bump |
| scripts/37-selinux.sh | Modified | 3 new policies (cdi, quadlet, sysext), CDI fcontext |
| system_files/usr/lib/bootc/kargs.d/00-cloudws.toml | Modified | 6 new SecureBlue kernel params |
| system_files/usr/lib/sysctl.d/99-cloudws-hardening.conf | Modified | 4 new sysctl params |
| system_files/usr/lib/ostree/prepare-root.conf | Modified | [root] section, composefs docs |
| image-versions.yml | **Added** | Base image digest pinning for Renovate |
| renovate.json | **Added** | Renovate Bot configuration |
| CHANGELOG-v2_1_0.md | **Added** | This file |

---

## Research Sources

This release incorporates findings from a comprehensive analysis of the bootc ecosystem:

- **bootc v1.11–v1.15**: composefs-native backend, kargs.d, tag-aware upgrades, soft reboot
- **Universal Blue**: Modular OCI composition, uupd unified updater, Renovate digest pinning
- **Bazzite April 2026**: Rechunking engine, SBOM changelogs, OpenSSF Scorecard, signed ISOs
- **SecureBlue**: 29-parameter kernel hardening audit, USBGuard policies, hardened_malloc
- **Fedora 44 Beta**: bootupd phase 1, NTSYNC, KMSCON, Podman 6, systemd 259.5
- **RHEL Image Mode**: Download-only upgrades, OpenSCAP integration, system-reinstall-bootc
- **bootc-image-builder**: ISO gpgkey=file:// fix, GitHub Actions quirks, BIB→image-builder-cli merger
- **NVIDIA**: CDI default mode (v1.19), CVE-2025-23266/23267 fixes, open modules for Blackwell
