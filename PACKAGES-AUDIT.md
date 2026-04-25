# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# Package Audit: Suggested Additions vs Current State

This audit cross-references the suggested "missing packages for portability" against
what CloudWS-bootc v2.1 PACKAGES.md already includes. Most suggestions are duplicates
of packages that are already present or pulled as dependencies.

---

## ALREADY PRESENT — No action needed

| Suggested Package | Already In | Section |
|-------------------|-----------|---------|
| `systemd-udev` | Base image (`fedora-bootc:rawhide`) | Core systemd |
| `NetworkManager` | Auto-dep of `gnome-control-center` | GNOME |
| `NetworkManager-wifi` | Explicit | `packages-gnome` |
| `wpa_supplicant` | Dep of `NetworkManager-wifi` | Auto |
| `lvm2` | Explicit | `packages-storage` |
| `btrfs-progs` | Explicit | `packages-storage` |
| `xfsprogs` | Explicit | `packages-storage` |
| `mesa-dri-drivers` | Explicit | `packages-gpu-mesa` |
| `vulkan-tools` | Explicit | `packages-gpu-mesa` and `packages-gaming` |
| `pipewire` | Auto-dep of `gnome-shell` | Auto |
| `pipewire-pulseaudio` | Explicit | `packages-gnome` |
| `pipewire-alsa` | Explicit | `packages-gnome` |
| `gstreamer1-plugins-base` | Explicit | `packages-gnome` |
| `gstreamer1` | Explicit | `packages-gnome` |
| `skopeo` | Explicit | `packages-containers` |
| `buildah` | Explicit | `packages-containers` |
| `podman` | Explicit | `packages-containers` |
| `cockpit` | Explicit | `packages-cockpit` (full suite) |
| `firewalld` | Explicit | `packages-security` |
| `rpm-ostree` | Explicit | `packages-containers` |
| `hyperv-daemons` | Explicit | `packages-guests` |
| `qemu-guest-agent` | Explicit | `packages-guests` |
| `open-vm-tools` | Explicit | `packages-guests` |
| `spice-vdagent` | Explicit | `packages-guests` |

## REJECTED — Wrong for CloudWS

| Suggested Package | Reason to Reject |
|-------------------|-----------------|
| `xorg-x11-server-Xorg` | CloudWS is Wayland-only. Fedora 43+ dropped X11 from GNOME repos. GNOME 50 removes X11 upstream. Adding X11 contradicts the project architecture. |
| `htop` | Explicitly removed in v2.0 changelog — replaced with `btop` (already in utils). |
| `dracut-live` | Only needed for PXE `pxe-tar-xz` image type. CloudWS deploys via RAW/VHDX/WSL/ISO/OCI — none require dracut-live. |
| `shim-signed` | Fedora names this `shim-x64`. It's part of the base bootc image's boot infrastructure and handled by `bootc install`. Not an in-image RPM to add. |
| `wslg` | WSLg is a Microsoft component running in the host WSL2 infrastructure, not a package inside Linux distros. CloudWS WSL2 support works via WSLg socket mounts automatically. |

## LEGITIMATE ADDITIONS — Consider for next release

| Package | Rationale | Suggested Section |
|---------|-----------|-------------------|
| `ntfs-3g` | Mount Windows NTFS volumes. Useful for dual-boot bare metal and Hyper-V scenarios where users need to access Windows partitions. | `packages-storage` |
| `podman-docker` | Provides `/usr/bin/docker` symlink to Podman. Zero overhead, eliminates "docker: command not found" for users migrating from Docker workflows. | `packages-containers` |
| `strace` | System call tracer. Essential diagnostic tool for debugging service startup failures, SELinux issues, and permission problems. | `packages-utils` |
| `lsof` | List open files. Critical for diagnosing "address already in use" and file-locking issues. | `packages-utils` |
| `iotop` | I/O monitoring. Useful for diagnosing slow storage and identifying I/O-heavy processes. Lightweight. | `packages-utils` |
| `efibootmgr` | EFI boot entry management. While `bootc install` handles initial setup, admins may need to reorder boot entries or remove stale ones post-install. | `packages-boot` |
| `nm-connection-editor` | GUI for advanced NetworkManager connection editing (bonding, bridging, VLANs). GNOME Settings covers basic Wi-Fi/Ethernet but not advanced cases. | `packages-gnome` (optional) |
| `cosign` | On-system image verification. Lets users verify CloudWS images and their own container images without needing a separate workstation. | `packages-security` |

## SUMMARY

- **24 packages** already present — no changes needed
- **5 packages** rejected — wrong for CloudWS architecture
- **8 packages** are legitimate additions worth evaluating
- Net delta: ~8 new packages across 4 sections

The audit confirms that CloudWS-bootc PACKAGES.md is already comprehensive for its
deployment targets. The "missing packages" list was largely written without reading
the existing manifest.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
