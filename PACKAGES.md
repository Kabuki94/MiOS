# CloudWS v2.1 — Package Manifest

This file is both documentation and the **single source of truth** for all packages installed in CloudWS.
Build scripts parse the fenced code blocks below using `scripts/lib/packages.sh`.
To add a package, add it to the appropriate section. One package per line.

**CHANGELOG v2.1:**
- Added bootupd (unified bootloader updates — Fedora 44 phase 1)
- Added dnf5-plugins (versionlock support for critical package pinning)
- Added systemd-boot-unsigned (UKI preparation — future composefs+UKI chain)
- Added libsss_nss_idmap (fixes sssd-related dep resolution on F44)
- Added tpm2-tools (TPM2 support for measured boot / future attestation)
- Added clevis, clevis-luks (automated LUKS unlock via TPM2/Tang)
- Moved driverctl from security to utils (better categorization)

**CHANGELOG v2.0 (previous):**
- Removed htop (use btop instead)
- Added nvidia-settings to NVIDIA section
- Added avahi/nss-mdns for .local network discovery
- Added network-discovery package section

---

## Repositories

RPMFusion Free + Nonfree for NVIDIA drivers and multimedia codecs.
CrowdSec official repo with Fedora 40 fallback for Rawhide compatibility.

```packages-repos
rpmfusion-free-release-rawhide
rpmfusion-nonfree-release-rawhide
fedora-workstation-repositories
dnf-plugins-core
dnf5-plugins
```

## Kernel

Kernel extras + development headers for akmod-nvidia and DKMS builds.
Base kernel ships with fedora-bootc:rawhide — NEVER upgrade it in-container.
Upgrading triggers dracut under tmpfs which breaks the initramfs.

```packages-kernel
kernel-modules-extra
kernel-devel
kernel-headers
kernel-tools
glibc-headers
glibc-devel
python3
```

## GNOME 50 Desktop

MINIMAL GNOME shell — infrastructure ONLY. NO viewer/editor apps as RPMs.
Epiphany (Flatpak browser) handles documents, photos, and media natively.
Steam, Wine, virt-manager, Waydroid are RPM exceptions (need system-level access).

GNOME 49+: systemd is a HARD dependency. gnome-session's built-in service
manager was removed. Full systemd user session support is required.
GNOME 50: X11 session removed upstream. Wayland-only (Fedora 43+ dropped X11).

```packages-gnome
# ── Core shell (auto-pulls: mutter, gjs, gtk4, libadwaita, gnome-desktop4,
#    gnome-session, gnome-settings-daemon, gsettings-desktop-schemas, colord,
#    dconf, adwaita-icon-theme, adwaita-cursor-theme, pipewire, polkit) ──
gnome-shell
gnome-session-wayland-session
gnome-control-center
gnome-keyring
gdm
# ── Desktop apps ──
ptyxis
nautilus
gnome-software
gnome-remote-desktop
gnome-backgrounds
# ── Extensions ──
gnome-shell-extension-appindicator
gnome-shell-extension-dash-to-dock
# ── Portals ──
xdg-user-dirs
xdg-utils
xdg-desktop-portal
xdg-desktop-portal-gnome
xdg-desktop-portal-gtk
# ── Audio ──
pipewire-alsa
pipewire-pulseaudio
wireplumber
# ── GStreamer (MUST be explicit — ucore fc43 base ships older GStreamer that
#    is ABI-incompatible with GNOME 50. Without these, gnome-shell crashes on
#    launch with "undefined symbol: gst_state_get_name" in libgstplay) ──
gstreamer1
gstreamer1-plugins-base
gstreamer1-plugins-good
# ── Hardware ──
upower
gnome-bluetooth
bluez
bluez-tools
# ── Flatpak (gnome-software manages these — no rpm-ostree plugin needed) ──
flatpak
# ── Filesystem access ──
gvfs
gvfs-smb
gvfs-mtp
# ── Networking ──
NetworkManager-wifi
NetworkManager-openvpn-gnome
# ── Locale ──
glibc-langpack-en
# ── Qt Adwaita theming ──
qt6-qtbase-gui
qt6-qtwayland
qadwaitadecorations-qt5
adw-gtk3-theme
```

## GNOME Core Apps (OPTIONAL — uncomment to include)

Optional GNOME Core Apps. ALL commented out by default — uncomment to include.
Epiphany (Flatpak browser) handles documents, photos, and media natively.

```packages-gnome-core-apps
# ── Viewers (uncomment to include) ──
# papers
# loupe
# showtime
# gnome-text-editor
# ── Utilities ──
# gnome-disk-utility
# gnome-system-monitor
# baobab
# gnome-connections
# gnome-tweaks
# file-roller
# resources
# gnome-calculator
# gnome-calendar
# gnome-contacts
# gnome-clocks
# gnome-weather
# gnome-maps
# gnome-characters
# gnome-font-viewer
# ── Media ──
# gnome-music
# snapshot
# decibels
# cheese
# ── System ──
# gnome-logs
# deja-dup
# simple-scan
# seahorse
# gnome-boxes
```

## GPU Drivers — Mesa (AMD / Intel / software fallback)

Universal Mesa stack supporting all AMD and Intel GPUs out of the box.
Mesa 26: ACO is now default shader compiler for RadeonSI.

```packages-gpu-mesa
mesa-vulkan-drivers
mesa-dri-drivers
mesa-va-drivers
vulkan-loader
vulkan-tools
libva-utils
linux-firmware
microcode_ctl
```

## GPU Drivers — AMD Compute (optional, fault-tolerant)

ROCm OpenCL/HIP for AMD compute workloads.

```packages-gpu-amd-compute
rocm-opencl
rocm-hip
rocm-runtime
rocm-smi
rocminfo
```

## GPU Drivers — Intel Compute (oneAPI Level Zero)

Intel GPU compute runtime for OpenCL and Level Zero API.
Supports Intel Arc, Iris Xe, and integrated GPUs.
All packages are in official Fedora repos — no extra repo needed.

```packages-gpu-intel-compute
intel-compute-runtime
intel-media-driver
level-zero
intel-gpu-tools
```

## GPU Drivers — NVIDIA (akmod, builds for any NVIDIA card)

NVIDIA proprietary drivers via RPMFusion akmod. Builds kmod at image time.
Driver 590+: Open kernel modules are DEFAULT for Turing (RTX 20+) and newer.
Blackwell (RTX 50): Open modules are the ONLY option — proprietary incompatible.
WARNING: RTX 50-series has a VFIO reset bug — see /usr/share/doc/cloudws-vfio-warning.txt
CDI is now the default mode in nvidia-container-toolkit v1.19+.

```packages-gpu-nvidia
akmod-nvidia
xorg-x11-drv-nvidia-cuda
nvidia-container-toolkit
nvidia-persistenced
nvidia-settings
xorg-x11-drv-nvidia-power
```

## Virtualization — KVM / QEMU / Libvirt

Full KVM stack with virt-manager GUI and firmware/security tooling.

```packages-virt
qemu-kvm
libvirt
virt-install
virt-manager
edk2-ovmf
swtpm
swtpm-tools
dnsmasq
mdevctl
libguestfs-tools
```

## Container Runtime

Podman, Buildah, Skopeo, bootc tooling, and OCI image building.

```packages-containers
podman
podman-compose
buildah
skopeo
bootc
bootc-image-builder
osbuild
osbuild-composer
osbuild-selinux
composer-cli
rpm-ostree
crun
netavark
aardvark-dns
slirp4netns
composefs
container-selinux
qemu-img
image-builder
dracut-live
squashfs-tools
selinux-policy-devel
```

## Boot & Update Management

Bootloader updates and system update tooling for bootc systems.
bootupd: unified bootloader update service (Fedora 44 phase 1).
dnf5-plugins: versionlock for pinning critical packages (Mesa, PipeWire, etc.)

```packages-boot
bootupd
dnf5-plugins
systemd-boot-unsigned
```

## Cockpit Web Management

Full Cockpit ecosystem with file browser and all plugins.
cockpit-pcp removed (PCP metrics now native in cockpit-bridge since Cockpit 326).

```packages-cockpit
cockpit
cockpit-system
cockpit-ws
cockpit-bridge
cockpit-storaged
cockpit-networkmanager
cockpit-packagekit
cockpit-podman
cockpit-machines
cockpit-ostree
cockpit-selinux
cockpit-files
pcp
pcp-system-tools
```

## Windows Interop & Remote Desktop

Tools for Hyper-V Enhanced Session, SMB, and xRDP over vsock.

```packages-wintools
xrdp
xorgxrdp-glamor
hyperv-tools
samba
samba-client
cifs-utils
```

## Security

Host-based IPS, application whitelisting, USB device control.
CRITICAL: nvidia-container-toolkit >= v1.17.7 required (CVE-2025-23266/23267).

```packages-security
crowdsec
crowdsec-firewall-bouncer-nftables
firewalld
fapolicyd
fapolicyd-selinux
usbguard
setroubleshoot-server
policycoreutils-python-utils
audit
tpm2-tools
clevis
clevis-luks
```

## Gaming

Steam, Wine, and Gamescope for gaming.
Gamescope SteamOS-mode GDM session baked via system_files (no COPR needed).
Removed lib32-gamemode and libstrangle (Arch-only, not in Fedora repos).
NTSYNC kernel module available in Fedora 44 for improved Wine/Steam performance.

```packages-gaming
steam
gamescope
gnome-shell-extension-gamemode
wine
wine-mono
wine-dxvk
winetricks
lutris
gamemode
mangohud
vulkan-tools
dosbox-staging
protontricks
```

## Guest Agents

Hypervisor integration services for VMs.

```packages-guests
qemu-guest-agent
hyperv-daemons
open-vm-tools
spice-vdagent
spice-webdavd
libvirt-nss
```

## Storage

Distributed/shared storage, multipath, iSCSI.

```packages-storage
nfs-utils
rpcbind
glusterfs
glusterfs-fuse
glusterfs-server
ceph-common
iscsi-initiator-utils
targetcli
device-mapper-multipath
sg3_utils
lvm2
stratis-cli
stratisd
xfsprogs
btrfs-progs
e2fsprogs
mdadm
```

## Ceph Distributed Storage

Cephadm orchestrator + CephFS kernel client for native distributed storage.
All Ceph server daemons (MON/OSD/MGR/MDS) run as Podman containers via cephadm.

```packages-ceph
ceph-common
cephadm
ceph-fuse
ceph-selinux
```

## K3s Lightweight Kubernetes

K3s binary is downloaded directly (not via dnf).
k3s-selinux only exists for RHEL/CentOS — not available on Fedora Rawhide.

```packages-k3s
container-selinux
```

## High Availability — Pacemaker / Corosync

Full HA cluster stack with fence agents and SBD.

```packages-ha
pacemaker
corosync
pcs
fence-agents-all
fence-virt
resource-agents
sbd
booth
booth-core
booth-test
dlm
corosync-qdevice
corosync-qnetd
libqb
libibverbs
```

## CLI Utilities

Common command-line tools and system utilities.

```packages-utils
git
tmux
vim-enhanced
wget2-wget
curl
btop
nvtop
fastfetch
lm_sensors
smartmontools
tuned
tuned-ppd
fuse
fuse3
7zip-standalone
unzip
rsync
tree
jq
yq
bc
distrobox
just
driverctl
```

## Android — Waydroid

Waydroid container runtime for Android apps.
Note: NVIDIA GPUs lack full 3D acceleration in Waydroid (Mesa/AMD/Intel only).

```packages-android
waydroid
```

## Looking Glass B7 — Build Dependencies

These packages are installed during the build to compile Looking Glass B7.
They are REMOVED after compilation to keep the image small.

```packages-looking-glass-build
cmake
gcc
gcc-c++
make
binutils
pkgconf-pkg-config
libglvnd-devel
fontconfig-devel
spice-protocol
nettle-devel
gnutls-devel
libXi-devel
libXinerama-devel
libXcursor-devel
libXpresent-devel
libxkbcommon-x11-devel
wayland-devel
wayland-protocols-devel
libdecor-devel
pipewire-devel
libsamplerate-devel
dkms
```

## Cockpit Plugin Build Dependencies

Build dependencies for Cockpit plugins from git.

```packages-cockpit-plugins-build
npm
gettext
```

## Network Discovery — Avahi / mDNS

mDNS/DNS-SD for automatic .local hostname discovery on LAN.
Every CloudWS instance advertises Cockpit and RDP services.

```packages-network-discovery
avahi
avahi-tools
nss-mdns
```


### Phosh (Mobile Session)
```packages-phosh
phosh
phoc
squeekboard
gnome-calls
feedbackd
```
