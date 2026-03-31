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

Minimal GNOME installation — individual packages only (NO @gnome-desktop group).
User-facing apps are Flatpaks. Only system RPMs here.

```packages-gnome
gnome-shell
gnome-session
gnome-settings-daemon
gnome-control-center
mutter
gjs
gnome-keyring
polkit
gnome-tweaks
gnome-shell-extensions
gnome-themes-extra
gnome-shell-extension-appindicator
gnome-shell-extension-dash-to-dock
adwaita-cursor-theme
adwaita-icon-theme
gnome-backgrounds
gsettings-desktop-schemas
colord
gdm
ptyxis
nautilus
file-roller
evince
loupe
totem
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
epiphany
dconf
gnome-software
gnome-software-rpm-ostree
gnome-system-monitor
gnome-disk-utility
gnome-remote-desktop
gvfs
gvfs-smb
gvfs-mtp
NetworkManager-wifi
NetworkManager-openvpn-gnome
glibc-langpack-en
```

## GPU Drivers — Mesa (AMD / Intel / software fallback)

Universal Mesa stack supporting all AMD and Intel GPUs out of the box.

```packages-gpu-mesa
mesa-vulkan-drivers
mesa-dri-drivers
mesa-va-drivers
mesa-vdpau-drivers
vulkan-loader
vulkan-tools
libva-utils
linux-firmware
amd-ucode
intel-ucode
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
| com.mattjakeman.ExtensionManager | flathub | GNOME Shell extension manager |
| io.podman_desktop.PodmanDesktop | flathub | Container management GUI |
| com.visualstudio.code | flathub | VS Code editor |
| com.usebottles.bottles | flathub-beta | Windows app runner (autostart) |

## GNOME Desktop Group (installed via @gnome-desktop)

The `@gnome-desktop` group installs the full GNOME Shell, session, settings daemon,
control center, mutter, gjs, gnome-keyring, polkit, and all core dependencies.
Individual packages in `packages-gnome` above are extras beyond the group.

## Totals

| Category | Count |
|----------|-------|
| RPM Packages (explicit) | ~225 |
| Flatpak Apps (pre-installed) | 4 |
| Git-cloned plugins | 3 (cockpit-benchmark, cockpit-zfs-manager, geist-font) |
| Binary installs | 1 (K3s) |
| Custom tools | 14 |
| Config files | 20+ |
| GDM sessions | 2 (GNOME Wayland, Steam Gamescope) |
