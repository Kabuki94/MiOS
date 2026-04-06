# CloudWS v1.3 — Package Manifest

This file is both documentation and the **single source of truth** for all packages installed in CloudWS.
Build scripts parse the fenced code blocks below using `scripts/lib/packages.sh`.
To add a package, add it to the appropriate section. One package per line.

---

## Repositories

RPMFusion Free + Nonfree for NVIDIA drivers and multimedia codecs.
CrowdSec official repo with Fedora 40 fallback for Rawhide compatibility.

```packages-repos
rpmfusion-free-release-rawhide
rpmfusion-nonfree-release-rawhide
fedora-workstation-repositories
dnf-plugins-core
```

## Kernel

Kernel upgrade + development headers required for akmod-nvidia.

```packages-kernel
kernel
kernel-core
kernel-modules
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

```packages-gnome
gnome-shell
gnome-session
gnome-session-wayland-session
gnome-settings-daemon
gnome-control-center
mutter
gjs
gnome-keyring
polkit
gdm
gtk4
libadwaita
gnome-desktop4
ptyxis
nautilus
gnome-shell-extension-appindicator
gnome-shell-extension-dash-to-dock
adwaita-cursor-theme
adwaita-icon-theme
gnome-backgrounds
gsettings-desktop-schemas
colord
xdg-user-dirs
xdg-utils
xdg-desktop-portal
xdg-desktop-portal-gnome
xdg-desktop-portal-gtk
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber
upower
gnome-bluetooth
bluez
bluez-tools
flatpak
dconf
gnome-software
gnome-software-rpm-ostree
gnome-remote-desktop
gvfs
gvfs-smb
gvfs-mtp
NetworkManager-wifi
NetworkManager-openvpn-gnome
glibc-langpack-en
qt6-qtbase-gui
qt6-qtwayland
adwaita-qt5
adwaita-qt6
qadwaitadecorations-qt5
qadwaitadecorations-qt6
```

## GNOME Core Apps (OPTIONAL — uncomment to include)

These are additional GNOME Core Apps. By default they are EXCLUDED to keep
the image lean. Epiphany (browser) handles documents, photos, and media.
To include any, remove the `#` prefix from the package line.

```packages-gnome-core-apps
# ── Viewers (browser handles these — only uncomment if you want dedicated apps) ──
# papers
# loupe
# showtime
# gnome-text-editor
#
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
#
# ── Media ──
# gnome-music
# snapshot
# decibels
# cheese
#
# ── System ──
# gnome-logs
# deja-dup
# simple-scan
# seahorse
# gnome-boxes
```

## GPU Drivers — Mesa (AMD / Intel / software fallback)

Universal Mesa stack supporting all AMD and Intel GPUs out of the box.

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

## GPU-PV Baseline (ALL images — bare metal, VM, container, WSL2, ISO)

Paravirtualized GPU components for universal portability. These install
unconditionally so the same image boots everywhere with GPU acceleration.
WSL2 gets mesa-d3d12 (WDDM→Gallium bridge), VMs get virglrenderer
(virtio-gpu 3D), containers get EGL/GLES for headless compute.

```packages-gpu-pv-baseline
mesa-libEGL
mesa-libGLES
mesa-libgbm
mesa-libGL
mesa-d3d12
virglrenderer
libglvnd
libglvnd-egl
libglvnd-gles
libglvnd-glx
libglvnd-opengl
mesa-libOpenCL
ocl-icd
clinfo
```

## GPU Drivers — AMD Compute (optional, fault-tolerant)

ROCm OpenCL/HIP for AMD compute workloads.

```packages-gpu-amd-compute
rocm-opencl
rocm-hip
```

## GPU Drivers — NVIDIA (akmod, builds for any NVIDIA card)

NVIDIA proprietary drivers via RPMFusion akmod. Builds kmod at image time.

```packages-gpu-nvidia
akmod-nvidia
xorg-x11-drv-nvidia-cuda
nvidia-container-toolkit
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
```

## Cockpit Web Management

Full Cockpit ecosystem with all plugins including Image Builder.

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
cockpit-pcp
pcp
pcp-system-tools
```

## Windows Interop & Remote Desktop

Tools for Hyper-V Enhanced Session, SMB, and xRDP over vsock.

```packages-wintools
xrdp
xorgxrdp
samba
samba-client
cifs-utils
```

## Security

Host-based IPS, application whitelisting, USB device control.

```packages-security
crowdsec
crowdsec-firewall-bouncer-nftables
firewalld
fapolicyd
usbguard
setroubleshoot-server
policycoreutils-python-utils
audit
driverctl
```

## Gaming

Steam, Wine, and Gamescope for SteamOS-mode GDM session.

```packages-gaming
steam
gamescope
gamescope-session-steam
wine
wine-mono
winetricks
lutris
gamemode
lib32-gamemode
mangohud
libobs
vulkan-tools
dosbox-staging
protontricks
libstrangle
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
These are the system-level prerequisites K3s needs.

```packages-k3s
container-selinux
selinux-policy-base
iptables
nftables
```

## High Availability

Pacemaker/Corosync clustering + fencing.

```packages-ha
pacemaker
corosync
pcs
fence-agents-all
resource-agents
sbd
dlm
booth-arbitrator
booth-core
booth-site
cluster-glue
cluster-glue-libs
python3-pcs
python3-pyparsing
ruby-devel
gcc
make
keepalived
haproxy
etcd
```

## VM High Availability — Shared Storage + Live Migration

Sanlock disk-based VM lock manager prevents split-brain in clustered libvirt.
VirtualDomain OCF resource agent allows Pacemaker to failover VMs automatically.

```packages-vm-ha
sanlock
sanlock-lib
libvirt-lock-sanlock
resource-agents
fence-virt
```

## Database Stack (BASE — baked into every image)

MariaDB 11.x + PostgreSQL + pgvector for AI embeddings. Every CloudWS node
is database-ready out of the box for HA cluster deployments. DbGate is
installed as Flatpak (see Flatpak section below).

```packages-database
mariadb-server
mariadb
mariadb-backup
mariadb-cracklib-password-check
postgresql-server
postgresql
postgresql-contrib
postgresql-server-devel
pgvector
libpq
libpq-devel
redis
```

## CLI Utilities

Essential command-line tools.

```packages-utils
git
jq
make
curl
wget
rsync
tmux
screen
tree
distrobox
cloud-init
polkit
udisks2
clevis
python3
python3-pip
python3-devel
lm_sensors
btop
nvtop
intel-gpu-tools
fastfetch
GeoIP
GeoIP-GeoLite-data
```

## Android

Waydroid — Android with GAPPS in native Wayland windows.

```packages-android
waydroid
```

## Looking Glass Build Dependencies (removed after compile)

Temporary packages for compiling Looking Glass B7 client.

```packages-looking-glass-build
cmake
gcc
gcc-c++
make
pkgconf
binutils
binutils-devel
libX11-devel
nettle-devel
libXi-devel
libXinerama-devel
libXcursor-devel
libXpresent-devel
libxkbcommon-devel
wayland-devel
wayland-protocols-devel
libsamplerate-devel
pulseaudio-libs-devel
pipewire-devel
spice-protocol
fontconfig-devel
freetype-devel
libXScrnSaver-devel
libXrandr-devel
libdecor-devel
libepoxy-devel
mesa-libEGL-devel
```

## Cockpit Plugins (npm build dependency)

```packages-cockpit-plugins-build
nodejs-npm
npm
```

## AI Post-Install Framework Dependencies

These packages support the `cloudws-ai-*` post-install commands.
The heavy AI stacks (CUDA, ROCm full, OpenVINO, oneAPI) are NOT baked
into the base image — they are fetched on-demand via `cloudws-ai-*`
commands. These are just the lightweight prerequisites.

```packages-ai-base
python3-pip
python3-devel
python3-virtualenv
gcc
gcc-c++
cmake
```

## Flatpak Applications (pre-installed, user-removable)

These are installed via `flatpak install`, not dnf.

| Flatpak ID | Source | Description |
|------------|--------|-------------|
| org.gnome.Epiphany | flathub | GNOME Web browser (docs, photos, media — replaces dedicated viewer apps) |
| org.gnome.Logs | flathub | systemd journal viewer |
| com.mattjakeman.ExtensionManager | flathub | GNOME Shell extension manager |
| io.podman_desktop.PodmanDesktop | flathub | Container management GUI |
| ca.andyholmes.Refine | flathub | Modern interface tweaker (replaces gnome-tweaks) |
| org.dbgate.DbGate | flathub | Universal database management GUI (MariaDB, PostgreSQL, Redis) |

## Totals

| Category | Count |
|----------|-------|
| RPM Packages (explicit) | ~280 |
| Flatpak Apps (pre-installed) | 7 |
| Git-cloned plugins | 3 (cockpit-benchmark, cockpit-zfs-manager, geist-font) |
| Binary installs | 1 (K3s) |
| Custom tools | 20+ |
| Config files | 20+ |
| GDM sessions | 2 (GNOME Wayland, Steam Gamescope) |
| Optional GNOME Core Apps | ~25 (uncomment to enable) |
