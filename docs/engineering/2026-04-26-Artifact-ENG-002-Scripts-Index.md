# 📜 MiOS Scripts Index
> **Generated:** 2026-04-26T21:09:24.016149
> **Status:** Automated Sync

```json:knowledge
{
  "summary": "Automated index of all MiOS automation scripts.",
  "logic_type": "automation",
  "tags": [
    "scripts",
    "automation",
    "index"
  ],
  "generated_at": "2026-04-26T21:09:24.016126"
}
```

This file provides a machine-readable and human-readable index of all automation scripts in the `scripts/` directory.

## `01-repos.sh`
- **Path:** `scripts/01-repos.sh`
- **Description:** MiOS v2.1.0 — 01-repos: Fedora 44 overlay on ucore (base kernel preserved)

## `02-kernel.sh`
- **Path:** `scripts/02-kernel.sh`
- **Description:** MiOS v2.1.0 — 02-kernel: Kernel extras + development headers

## `05-enable-external-repos.sh`
- **Path:** `scripts/05-enable-external-repos.sh`
- **Description:** scripts/05-enable-external-repos.sh

## `08-system-files-overlay.sh`
- **Path:** `scripts/08-system-files-overlay.sh`
- **Description:** scripts/08-system-files-overlay.sh - MiOS v2.1.0

## `10-gnome.sh`
- **Path:** `scripts/10-gnome.sh`
- **Description:** MiOS v2.1.0 — 10-gnome: GNOME 50 desktop — PURE BUILD-UP

## `11-hardware.sh`
- **Path:** `scripts/11-hardware.sh`
- **Description:** MiOS v2.1.0 — 11-hardware: GPU drivers (Mesa + AMD ROCm + Intel + NVIDIA)

## `12-virt.sh`
- **Path:** `scripts/12-virt.sh`
- **Description:** MiOS v2.1.0 — 12-virt: Virtualization, containers, orchestration, gaming

## `13-ceph-k3s.sh`
- **Path:** `scripts/13-ceph-k3s.sh`
- **Description:** MiOS v2.1.0 — 13-ceph-k3s: Ceph distributed storage + K3s Kubernetes

## `18-apply-boot-fixes.sh`
- **Path:** `scripts/18-apply-boot-fixes.sh`
- **Description:** ─────────────────────────────────────────────────────────────────────────────

## `19-k3s-selinux.sh`
- **Path:** `scripts/19-k3s-selinux.sh`
- **Description:** shellcheck source=lib/common.sh

## `20-fapolicyd-trust.sh`
- **Path:** `scripts/20-fapolicyd-trust.sh`
- **Description:** shellcheck source=lib/common.sh

## `20-services.sh`
- **Path:** `scripts/20-services.sh`
- **Description:** MiOS v2.1.0 — 20-services: Enable systemd services + bare-metal/VM gating

## `21-moby-engine.sh`
- **Path:** `scripts/21-moby-engine.sh`
- **Description:** Normalize to LF line endings (fixes SC1017)

## `22-freeipa-client.sh`
- **Path:** `scripts/22-freeipa-client.sh`
- **Description:** 22-freeipa-client.sh — install FreeIPA/SSSD client + arm zero-touch enrollment.

## `23-uki-render.sh`
- **Path:** `scripts/23-uki-render.sh`
- **Description:** shellcheck source=lib/common.sh

## `25-firewall-ports.sh`
- **Path:** `scripts/25-firewall-ports.sh`
- **Description:** During an OCI container build, the firewalld daemon is not running.

## `26-gnome-remote-desktop.sh`
- **Path:** `scripts/26-gnome-remote-desktop.sh`
- **Description:** Pre-emptively disable/mask legacy xrdp services just in case they bleed in from a base image

## `30-locale-theme.sh`
- **Path:** `scripts/30-locale-theme.sh`
- **Description:** MiOS v2.1.0 — 30-locale-theme: Unified dark theme for EVERY window type

## `31-user.sh`
- **Path:** `scripts/31-user.sh`
- **Description:** MiOS v2.1.0 — 31-user: PAM, user creation, groups, sudoers

## `32-hostname.sh`
- **Path:** `scripts/32-hostname.sh`
- **Description:** MiOS v2.1.0 — 32-hostname: Unique per-instance hostname

## `33-firewall.sh`
- **Path:** `scripts/33-firewall.sh`
- **Description:** MiOS v2.1.0 — 33-firewall: Firewall configuration script

## `34-gpu-detect.sh`
- **Path:** `scripts/34-gpu-detect.sh`
- **Description:** MiOS v2.1.0 — 34-gpu-detect: Bridge to GPU detection service

## `35-gpu-passthrough.sh`
- **Path:** `scripts/35-gpu-passthrough.sh`
- **Description:** MiOS v2.1.0 - 35-gpu-passthrough.sh

## `35-gpu-pv-shim.sh`
- **Path:** `scripts/35-gpu-pv-shim.sh`
- **Description:** scripts/35-gpu-pv-shim.sh - MiOS v2.1.0

## `35-init-service.sh`
- **Path:** `scripts/35-init-service.sh`
- **Description:** MiOS v2.1.0 — 35-init-service: Bridge to Unified Role Engine

## `36-akmod-guards.sh`
- **Path:** `scripts/36-akmod-guards.sh`
- **Description:** scripts/36-akmod-guards.sh - MiOS v2.1.0

## `36-tools.sh`
- **Path:** `scripts/36-tools.sh`
- **Description:** MiOS v2.1.0 — 36-tools: CLI tools and consolidated mios command

## `37-aichat.sh`
- **Path:** `scripts/37-aichat.sh`
- **Description:** 🌐 MiOS — Cloud Native Operating System

## `37-ollama-prep.sh`
- **Path:** `scripts/37-ollama-prep.sh`
- **Description:** 🌐 MiOS — Cloud Native Operating System

## `37-selinux.sh`
- **Path:** `scripts/37-selinux.sh`
- **Description:** MiOS v2.1.0 — 37-selinux: Build-time SELinux policy fixes

## `38-vm-gating.sh`
- **Path:** `scripts/38-vm-gating.sh`
- **Description:** MiOS v2.1.0 — 38-vm-gating: VM service gating + Hyper-V Enhanced Session

## `39-desktop-polish.sh`
- **Path:** `scripts/39-desktop-polish.sh`
- **Description:** MiOS v2.1.0 — 39-desktop-polish: Desktop entries, Cockpit webapp, MOTD

## `40-composefs-verity.sh`
- **Path:** `scripts/40-composefs-verity.sh`
- **Description:** 40-composefs-verity.sh - promote composefs from default (yes) to verity mode

## `42-cosign-policy.sh`
- **Path:** `scripts/42-cosign-policy.sh`
- **Description:** scripts/42-cosign-policy.sh - MiOS v2.6.3

## `43-uupd-installer.sh`
- **Path:** `scripts/43-uupd-installer.sh`
- **Description:** 43-uupd-installer.sh - install uupd + greenboot (from PACKAGES.md

## `44-podman-machine-compat.sh`
- **Path:** `scripts/44-podman-machine-compat.sh`
- **Description:** 44-podman-machine-compat.sh - Podman-machine backend compatibility.

## `45-nvidia-cdi-refresh.sh`
- **Path:** `scripts/45-nvidia-cdi-refresh.sh`
- **Description:** 45-nvidia-cdi-refresh.sh - wire up NVIDIA CDI auto-refresh services.

## `46-greenboot.sh`
- **Path:** `scripts/46-greenboot.sh`
- **Description:** 46-greenboot.sh - wire greenboot services; package installs via PACKAGES.md

## `47-hardening.sh`
- **Path:** `scripts/47-hardening.sh`
- **Description:** 47-hardening.sh - enable hardening services (USBGuard, auditd).

## `49-finalize.sh`
- **Path:** `scripts/49-finalize.sh`
- **Description:** 49-finalize.sh - final cleanup, systemd preset application, image linting

## `52-bake-kvmfr.sh`
- **Path:** `scripts/52-bake-kvmfr.sh`
- **Description:** 52-bake-kvmfr.sh - compile Looking Glass kvmfr kmod against the ucore-hci

## `53-bake-lookingglass-client.sh`
- **Path:** `scripts/53-bake-lookingglass-client.sh`
- **Description:** 53-bake-lookingglass-client.sh - git clone Looking Glass B7, cmake/make,

## `98-boot-config.sh`
- **Path:** `scripts/98-boot-config.sh`
- **Description:** MiOS v2.1.0 — 98-boot-config: Boot console + service configuration

## `99-cleanup.sh`
- **Path:** `scripts/99-cleanup.sh`
- **Description:** MiOS v2.1.0 — 99-cleanup: Final image cleanup (mirrors ucore/cleanup.sh)

## `99-postcheck.sh`
- **Path:** `scripts/99-postcheck.sh`
- **Description:** 99-postcheck.sh - build-time technical invariant validation

## `ai-bootstrap.sh`
- **Path:** `scripts/ai-bootstrap.sh`
- **Description:** MiOS Omni-Agent Bootstrap Script

## `bcvk-wrapper.sh`
- **Path:** `scripts/bcvk-wrapper.sh`
- **Description:** MiOS v2.1.0 — Ephemeral QEMU boot test

## `build.sh`
- **Path:** `scripts/build.sh`
- **Description:** MiOS v2.1.0 — Master build runner

## `enroll-mok.sh`
- **Path:** `scripts/enroll-mok.sh`
- **Description:** enroll-mok.sh — MiOS Secure Boot MOK enrollment helper.

## `generate-mok-key.sh`
- **Path:** `scripts/generate-mok-key.sh`
- **Description:** generate-mok-key.sh — one-shot MiOS MOK key generator.

## `smoke-check.sh`
- **Path:** `scripts/smoke-check.sh`
- **Description:** MiOS v2.1.0 — Post-boot serial log smoke check

