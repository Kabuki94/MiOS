# CloudWS v0.1.8 CHANGELOG

**Release Date:** April 6, 2026
**Codename:** Intelligence Update
**Sources:** Universal Blue, Bazzite, Bluefin, SecureBlue, bootc v1.15, Fedora Rawhide fc45

---

## Breaking Changes

- **systemd 260**: cgroup v1 support REMOVED. All services must use cgroup v2.
- **systemd 260**: SysV service scripts no longer supported.
- **GNOME 49+**: systemd is a HARD dependency. gnome-session built-in service manager removed.
- **Kernel 7.0**: kernel-modules-core split from kernel-modules (added to PACKAGES.md).
- **NVIDIA 590**: Pascal (GTX 10xx) support dropped. Open kernel modules default for Turing+.

## Containerfile Improvements

- **dnf5 cache mount** (`--mount=type=cache,dst=/var/cache/libdnf5`): 5-10x faster rebuilds
- **tmpfs mount** (`--mount=type=tmpfs,dst=/tmp`): Prevents /tmp artifacts from bloating layers
- **`/opt → /var/opt` symlink**: Makes /opt writable on immutable filesystem (Universal Blue pattern)
- **`CMD ["/sbin/init"]`**: bootc convention for bootable images
- **Post-build validation**: Verifies critical packages installed, checks for footgun packages
- **Third-party repo disable**: RPMFusion/Terra disabled after build (Bazzite pattern)

## New System Files

- **`/usr/lib/bootc/kargs.d/00-cloudws.toml`**: Declarative kernel boot arguments via bootc v1.11+ drop-in directory. Ships IOMMU, NVIDIA DRM, and security hardening params (slab_nomerge, init_on_alloc, pti, vsyscall=none) without bootloader modification.
- **`/usr/lib/ostree/prepare-root.conf`**: Enables composefs for verified boot filesystem with content-addressed dedup.
- **`/usr/lib/sysctl.d/99-cloudws-hardening.conf`**: SecureBlue-style kernel security hardening (kptr_restrict, dmesg_restrict, ptrace_scope, network hardening, fs protection).

## Build System

- **Repo priority hierarchy** (01-repos.sh): CrowdSec(80) < Terra(85) < RPMFusion(90) < Fedora(99) — Bazzite pattern
- **Post-build package validation** (build.sh): Verifies 14 critical packages, flags footgun packages
- **CrowdSec repo** moved from 12-virt.sh to 01-repos.sh for proper initialization order

## PACKAGES.md Fixes

- **Fixed**: Duplicate `pcp` and `pcp-system-tools` entries in Cockpit section
- **Fixed**: Removed `lib32-gamemode` and `libstrangle` (Arch-only, not in Fedora repos)
- **Added**: `kernel-modules-core` (kernel 7.0 split)
- **Added**: `container-selinux` and `k3s-selinux` to new K3s prerequisites section
- **Added**: `nvidia-persistenced` to NVIDIA section
- **Added**: `composefs` and `container-selinux` to containers section

## GPU / VFIO

- **RTX 50-series VFIO reset bug**: Detection in GPU auto-detect service, user warning at boot, documentation at `/usr/share/doc/cloudws-vfio-warning.txt`
- **NVIDIA open kernel modules**: `nvidia-open.conf` modprobe config for Turing+ default
- **New tool**: `cloudws-vfio-check` validates IOMMU, vfio modules, NVIDIA GPU detection, RTX 50 warning

## Looking Glass B7

- **`-DENABLE_LIBDECOR=ON`**: Required for GNOME Wayland window decorations
- **`-DENABLE_PIPEWIRE=ON`**: PipeWire audio support
- **Force OpenGL renderer**: Config at `/etc/skel/.config/looking-glass/client.ini` fixes NVIDIA+Wayland flicker
- **KVMFR module**: SELinux policy (`cloudws_kvmfr`) allows svirt_t access to /dev/kvmfr0

## Security Hardening

- **Kernel boot params**: slab_nomerge, init_on_alloc=1, page_alloc.shuffle=1, randomize_kstack_offset=on, pti=on, vsyscall=none via bootc kargs.d
- **Network sysctl**: tcp_syncookies, accept_redirects=0, send_redirects=0, rp_filter=1, log_martians=1
- **Process isolation**: ptrace_scope=2, unprivileged_bpf_disabled=1, bpf_jit_harden=2
- **File protection**: protected_hardlinks=1, protected_symlinks=1, protected_fifos=2, protected_regular=2

## SELinux

- **New policy**: `cloudws_portabled` — systemd-portabled D-Bus for sysext/confext (systemd 258+)
- **New policy**: `cloudws_kvmfr` — Looking Glass shared memory device access for VMs

## K3s

- **Pinned version**: v1.32.3+k3s1 for reproducible builds
- **SELinux**: container-selinux + k3s-selinux installed BEFORE K3s binary
- **Config**: `/etc/rancher/k3s/config.yaml` with selinux: true, traefik disabled

## Service Management

- **Fixed**: pmcd/pmlogger services no longer enabled (only pmproxy is installed)
- **Added**: podman-auto-update.timer for quadlet auto-updates
- **Added**: bootloader-update.service for bootc systems
- **Podman quadlet example**: CrowdSec dashboard at `/usr/share/containers/systemd/`

## Tools

- **Updated**: `cloudws-update` with localhost origin detection and fix
- **New**: `cloudws-vfio-check` — VFIO passthrough readiness checker
- **Updated**: `cloudws()` help function lists all v1.3 tools
- **Updated**: MOTD/banner to v1.3

---

## Files Changed (13 files)

| File | Status | Description |
|------|--------|-------------|
| VERSION | Modified | 1.2.0 → 1.3.0 |
| Containerfile | Modified | dnf5 cache, tmpfs, /opt symlink, validation, repo disable |
| PACKAGES.md | Modified | Duplicate fix, name corrections, new packages |
| scripts/build.sh | Modified | Post-build validation, summary |
| scripts/01-repos.sh | Modified | Priority hierarchy, CrowdSec repo |
| scripts/02-kernel.sh | Modified | kernel-modules-core, version logging |
| scripts/10-gnome.sh | Modified | GNOME 49+ systemd notes, Bibata 2.0.8, Flatseal |
| scripts/11-hardware.sh | Modified | NVIDIA open modules, RTX 50 warning |
| scripts/12-virt.sh | Modified | LG B7 libdecor, K3s pin, quadlet |
| scripts/20-services.sh | Modified | pmcd fix, podman-auto-update, systemd 260 |
| scripts/99-overrides.sh | Modified | RTX 50 detect, vfio-check tool, SELinux policies |
| push-to-github.ps1 | Modified | v1.3 new file verification |
| system_files/ (3 new) | Added | kargs.d, composefs, sysctl hardening |
