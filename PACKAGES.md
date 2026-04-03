# CloudWS v1.0 — Package Manifest

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

MINIMAL GNOME shell — system infrastructure ONLY. NO user apps as RPMs.
ALL user-facing apps are Flatpaks (uninstallable by user).
Steam, Wine, virt-manager, Waydroid are RPM exceptions (need system-level access).

```packages-gnome
gnome-shell
gnome-session
gnome-settings-daemon
gnome-control-center
mutter
gjs
gnome-keyring
polkit
gdm
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
```

## GNOME Core Apps (OPTIONAL — uncomment to include)

These are the full GNOME Core Apps suite. By default they are EXCLUDED to keep
the image lean. To include them, remove the `#` prefix from every package line
below. All apps listed here get sorted into GNOME Shell app folders automatically
by 99-overrides.sh (whether included as RPMs or not — Flatpak versions also get
folder assignments via dconf).

**To enable:** uncomment the block below (remove the leading `#` from each line).

```packages-gnome-core-apps
# ── Productivity ──
# gnome-text-editor
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
# loupe
# gnome-music
# totem
# snapshot
# decibels
# cheese
#
# ── Utilities ──
# gnome-disk-utility
# gnome-system-monitor
# gnome-logs
# baobab
# gnome-connections
# gnome-tweaks
# deja-dup
# file-roller
# evince
# simple-scan
# seahorse
# gnome-boxes
```

**App Folder Assignments** (applied by 99-overrides.sh dconf overlay regardless of install state):

| Folder | Apps |
|--------|------|
| Productivity | Text Editor, Calculator, Calendar, Contacts, Clocks, Weather, Maps, Characters, Fonts |
| Media | Loupe, Music, Videos, Snapshot, Decibels, Cheese |
| Utilities | Disks, System Monitor, Logs, Disk Usage, Connections, Tweaks, Backups, Archives, Document Viewer, Scanner, Passwords, Boxes |
| Internet | Epiphany, Firefox (if installed via Flatpak) |
| Development | VSCodium, Podman Desktop, Ptyxis |
| Gaming | Steam, Lutris, Bottles, DOSBox Staging |

## GPU Drivers — Mesa (AMD / Intel / software fallback)

Universal Mesa stack supporting all AMD and Intel GPUs out of the box.
- AMD CPU microcode is inside `linux-firmware` (not a separate `amd-ucode` package on Fedora)
- Intel CPU microcode is inside `microcode_ctl` (not a separate `intel-ucode` package on Fedora)
- VDPAU is legacy — modern video decode uses VA-API via `mesa-va-drivers` (NVIDIA provides its own VDPAU)

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
cockpit-machines
cockpit-podman
cockpit-ostree
cockpit-storaged
cockpit-networkmanager
cockpit-selinux
cockpit-image-builder
cockpit-files
pcp
cockpit-pcp
pcp-zeroconf
```

## Windows Image Building Tools

Tools for building Windows ISOs with UUP Dump (aria2c, cabextract, wimlib, chntpw).

```packages-wintools
aria2
cabextract
wimlib-utils
chntpw
genisoimage
```

## Security & IPS

Firewall, intrusion prevention, application control, USB protection.

```packages-security
firewalld
chrony
zram-generator
fapolicyd
usbguard
policycoreutils-python-utils
checkpolicy
ca-certificates
```

## Performance & Gaming

TuneD power management, Gamescope SteamOS-mode, Steam, Wine.

```packages-gaming
tuned
tuned-ppd
tuned-utils
tuned-profiles-cpu-partitioning
tuned-profiles-realtime
gamemode
mangohud
steam
gamescope
wine
winetricks
lutris
dosbox-staging
steam-devices
driverctl
```

## Guest Agents & Remote Access

Hypervisor guest agents for portability across Hyper-V, QEMU, VMware.
xRDP for remote desktop access.

```packages-guests
hyperv-daemons
qemu-guest-agent
open-vm-tools
spice-vdagent
xrdp
xorgxrdp
```

## Storage & Networking

Samba, NFS, iSCSI, multipath, network diagnostics.

```packages-storage
cifs-utils
virtiofsd
lvm2
mdadm
btrfs-progs
samba
samba-client
nfs-utils
openssh-server
tailscale
nvme-cli
device-mapper-multipath
sg3_utils
socat
nmap-ncat
tcpdump
iptables-nft
conntrack-tools
```

## High Availability / Clustering

Pacemaker/Corosync HA, distributed storage, Kubernetes support.

```packages-ha
corosync
pacemaker
pcs
fence-agents-all
resource-agents
keepalived
haproxy
sanlock
libvirt-lock-sanlock
iscsi-initiator-utils
targetcli
ceph-common
glusterfs
glusterfs-server
glusterfs-fuse
glusterfs-cli
etcd
helm
wireguard-tools
```

## System Utilities

CLI tools, cloud deployment, development essentials.

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

## Flatpak Applications (pre-installed, user-removable)

These are installed via `flatpak install`, not dnf.

| Flatpak ID | Source | Description |
|------------|--------|-------------|
| org.gnome.Epiphany | flathub | GNOME Web browser (WebKitGTK) |
| org.gnome.Logs | flathub | systemd journal viewer |
| com.mattjakeman.ExtensionManager | flathub | GNOME Shell extension manager |
| io.podman_desktop.PodmanDesktop | flathub | Container management GUI |
| com.vscodium.codium | flathub | VSCodium editor |

## Totals

| Category | Count |
|----------|-------|
| RPM Packages (explicit) | ~225 |
| Flatpak Apps (pre-installed) | 5 |
| Git-cloned plugins | 3 (cockpit-benchmark, cockpit-zfs-manager, geist-font) |
| Binary installs | 1 (K3s) |
| Custom tools | 14 |
| Config files | 20+ |
| GDM sessions | 2 (GNOME Wayland, Steam Gamescope) |
| Optional GNOME Core Apps | ~30 (uncomment to enable) |
