# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# MiOS v2.1.0 - BAKE IN EVERYTHING

## What went wrong in v2.1.0 / v2.1.0

Two violations of the project principle
**"Every image is fully self-building and fully featured"**:

### 1. PACKAGES-UNIFIED-EXTRAS.md was documentation, not installation

v2.1.0 shipped a manifest listing k3s, ceph-common, pacemaker, corosync, pcs,
gamescope, steam, waydroid, libvirt, crowdsec, gnome-shell, gdm, etc. -
but no build script actually invoked `dnf5 install` on any of it. The
manifest was parsed by `scripts/lib/packages.sh` only if pre-existing
`PACKAGES.md` logic picked up the new file, which it did not.

Result: a user boots the image, runs `ujust mios-set-role k3s-master`,
and discovers k3s is not installed. Same for every other "role-specific"
capability.

### 2. Looking Glass (kvmfr + client) was deferred to "runtime compile"

v2.1.0 explicitly wrote "kvmfr becomes a runtime feature (compile on first
enable)". That is NOT baked in. The project principle does not have an
exception for kernel modules.

## Fix

Four new build scripts, all running inside the Containerfile - nothing is
deferred, nothing is runtime-compiled.

### scripts/50-install-repos.sh

Enables all external repos the unified packages depend on:
- RPM Fusion free + nonfree
- ublue-os/packages COPR (uupd - idempotent; already enabled in 43)
- hikariknight/looking-glass-kvmfr COPR (akmod-kvmfr)
- bazzite-org/bazzite COPR (patched Gamescope with CAP_SYS_NICE)
- bazzite-org/bazzite-multilib COPR (32-bit Steam deps)
- packagecloud.io/crowdsec/crowdsec (CrowdSec + bouncer)
- rpm.rancher.io/k3s (k3s-selinux policy RPM)

### scripts/51-install-unified-packages.sh

One script, one place, explicit `dnf5 install` calls for every package.
Organized into groups:
- build-infra (bootc, cosign, gcc, cmake, meson, rust/cargo, git)
- machine-backend (cloud-init, qemu-guest-agent, spice-vdagent, wslu)
- security (usbguard, audit, aide, openscap, nftables, firewalld)
- crowdsec
- k8s-runtime (podman, toolbox, distrobox, kubectl, helm + k3s binary pre-download)
- nvidia-userspace (toolkit; kmod is from ucore-hci base)
- virtualization (libvirt, qemu-kvm, edk2-ovmf, swtpm, virt-manager, cockpit-machines)
- ha-storage (pacemaker, corosync, pcs, fence-agents, ceph-common)
- updater (greenboot + default-health-checks)
- desktop (gnome-shell, gdm, gnome-remote-desktop, pipewire, wireplumber)
- gaming (gamescope, steam, steam-devices, mangohud, gamemode)
- waydroid
- lg-build-deps (kernel-devel, all Looking Glass client -devel deps)
- amd-compute (rocm-runtime, rocm-smi, rocminfo)
- intel-compute (intel-compute-runtime, intel-media-driver)

Each group is independent - a failure in one does not abort the build. End
of script logs a summary of which groups succeeded/failed.

### scripts/52-bake-kvmfr.sh

Inside the container build:
1. Detects the shipped kernel via `ls /usr/lib/modules/`.
2. Ensures `kernel-devel-$KVER` is present.
3. Installs `akmod-kvmfr` from hikariknight COPR.
4. Runs `akmods --force --kernels $KVER`.
5. Verifies `/usr/lib/modules/$KVER/extra/kvmfr/kvmfr.ko` exists.
6. Runs `depmod -a`.
7. Signs the kmod with the ublue MOK if the private key is present (it
   is NOT in the image for security - signing is a ublue-ci-side step;
   the kmod ships signed-by-ublue when pulled from the COPR).

### scripts/53-bake-lookingglass-client.sh

Inside the container build:
1. `git clone --branch B7 --recurse-submodules gnif/LookingGlass`.
2. cmake + make -j$(nproc) in client/build/.
3. `install -Dm0755 looking-glass-client /usr/bin/looking-glass-client`.
4. Ships a `.desktop` entry at
   `/usr/share/applications/looking-glass.desktop`.
5. Removes the source tree.
6. Verifies `/usr/bin/looking-glass-client --version` works.

The toolchain (gcc, cmake, make, git) stays in the image per the
self-building principle.

### New system_files

- `etc/modprobe.d/kvmfr.conf` - `options kvmfr static_size_mb=128`
- `usr/lib/udev/rules.d/99-kvmfr.rules` - kvm group, 0660, uaccess tag
- `etc/modules-load.d/mios-vfio.conf` - vfio, vfio_iommu_type1, vfio_pci
  at boot (kvmfr deliberately NOT autoloaded - reserves shmem; users
  enable via ujust when they actually want Looking Glass)
- `usr/lib/systemd/system/mios-kvmfr-load.service` - modprobe kvmfr +
  fix /dev/kvmfr0 permissions. Disabled by default; enabled via:

### New ujust recipes

- `ujust mios-looking-glass-enable` - enable kvmfr autoload + modprobe now
- `ujust mios-looking-glass-disable` - reverse
- `ujust mios-looking-glass-status` - lsmod / device / binary version

## What's still NOT baked in (and why that's correct)

These genuinely require runtime context and are appropriately role-based:

- **K3s server/agent activation** - binary is baked in; `k3s server` vs
  `k3s agent` is a runtime choice based on role.conf. No compile deferred.
- **Ceph cluster bootstrap** - ceph-common is baked in; which node is a
  mon, mgr, osd, mds is configured at runtime via `cephadm bootstrap` or
  role-specific config. No compile deferred.
- **Pacemaker cluster configuration** - packages baked in; cluster join
  is runtime.
- **CrowdSec API key / bouncer registration** - package baked in;
  bouncer registration is per-install and happens on first boot
  (mios-crowdsec-init.service).

## Migration from v2.1.0

`bootc upgrade` once v2.1.0 publishes. First boot will be notably slower
as initial systemd-tmpfiles, first-boot services, and uupd reconcile
against the larger installed package set. Expect ~300-500 MiB additional
image size from the unified package install.

## Known tradeoffs of baked-in approach

- **Image size**: growing from ~2.5 GiB (v2.1.0) to ~3.5-4 GiB
  (v2.1.0). Acceptable - composefs dedup and lazy inode allocation keep
  disk usage sane. OCI layer cache on GHCR absorbs the pull cost after
  first fetch.
- **Build time**: CI builds grow from ~6 min to ~15-20 min. Mostly
  Looking Glass compile + akmod build. Acceptable for a 6h uupd
  cadence.
- **Steam + Gamescope multilib**: 32-bit dependencies pull in a lot of
  glibc.i686 + libX11.i686 etc. Costs ~200 MiB but required for Proton.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
