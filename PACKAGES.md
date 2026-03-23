# CloudWS v3.3 — Complete Package Inventory

## REPOSITORIES (01-repos.sh)

| Package | Description |
|---------|-------------|
| rpmfusion-free-release-rawhide | RPMFusion free (codecs, drivers) |
| rpmfusion-nonfree-release-rawhide | RPMFusion nonfree (NVIDIA) |
| fedora-workstation-repositories | Fedora workstation third-party repos |
| dnf-plugins-core | DNF package manager plugins |
| crowdsec repo (curl script) | CrowdSec official repository |

## KERNEL (02-kernel.sh)

| Package | Description |
|---------|-------------|
| kernel / kernel-core / kernel-modules | Linux kernel |
| kernel-devel / kernel-headers | Kernel build headers (akmod-nvidia) |
| kernel-modules-extra | VFIO, USB, extra modules |
| kernel-tools | cpupower, perf |
| glibc-headers / glibc-devel | C library development |
| python3 | Python interpreter |
| ntsync.h (curl) | NTSync header for Wine/Proton |

## GNOME 50 DESKTOP (01-gnome.sh — RPM Layer)

### Core Shell
gdm, gnome-shell, gnome-session, gnome-settings-daemon, gnome-control-center, mutter, gjs, gnome-keyring, polkit

### File Management & Terminal
nautilus, ptyxis (container-aware terminal)

### System Utilities
gnome-software, gnome-disk-utility, gnome-system-monitor, gnome-extensions-app

### Shell Extensions
gnome-shell-extension-appindicator (system tray), gnome-shell-extension-dash-to-dock (bottom dock), gnome-shell-extension-tiling-assistant (quarter-tiling + snap assist)

### Virtual Filesystem
gvfs, gvfs-smb, gvfs-mtp, gvfs-goa, gvfs-afc

### Portal & Desktop Integration
xdg-desktop-portal, xdg-desktop-portal-gnome, xdg-desktop-portal-gtk, xdg-user-dirs, xdg-utils

### Networking
NetworkManager-wifi, NetworkManager-openvpn-gnome

### Flatpak Infrastructure
flatpak

### Theme & Appearance
adwaita-cursor-theme, adwaita-icon-theme, gnome-backgrounds, gsettings-desktop-schemas, colord, gnome-color-manager

### Qt Theme Bridge (dynamic GNOME theme following)
adwaita-qt5, adwaita-qt6, qadwaitadecorations-qt5, qadwaitadecorations-qt6, qgnomeplatform-qt5, qgnomeplatform-qt6

### Audio / Bluetooth / Power
pipewire, pipewire-alsa, pipewire-pulseaudio, wireplumber, upower, gnome-bluetooth, bluez, bluez-tools

### Remote Desktop & Graphics
gnome-remote-desktop, wayland-utils, vulkan-validation-layers, mesa-libEGL, mesa-libgbm

### Locale & Font
glibc-langpack-en, geist-font (git clone)

## MULTIMEDIA (01-gnome.sh — RPMFusion)
ffmpeg, gstreamer1-plugins-base, gstreamer1-plugins-good, gstreamer1-plugins-bad-free, gstreamer1-plugins-bad-freeworld, gstreamer1-plugins-ugly, gstreamer1-plugins-ugly-free, gstreamer1-libav, gstreamer1-vaapi, libavcodec-freeworld

## FLATPAK APPLICATIONS (Baked — 5 apps)

| Flatpak ID | Source | Description |
|------------|--------|-------------|
| org.gnome.Epiphany | gnome-nightly | Web browser (handles PDFs, images, Cockpit) |
| org.gnome.baobab | gnome-nightly | Disk Usage Analyzer (storage management) |
| io.podman_desktop.PodmanDesktop | flathub | Container management GUI |
| com.usebottles.bottles | flathub | Windows app runner (Wine prefix manager) |
| com.vscodium.codium | flathub | Code editor (VSCodium — MIT-licensed VS Code) |

### Flatpak Runtimes (auto-installed)
org.gnome.Platform//master, org.gnome.Platform//50, org.freedesktop.Platform//25.08, GL drivers, i386 compat

## HARDWARE DRIVERS (01-hardware.sh)

### GPU (Mesa + NVIDIA)
mesa-vulkan-drivers, mesa-dri-drivers, mesa-va-drivers, vulkan-loader, vulkan-tools, libva-utils, linux-firmware, microcode_ctl, rocm-opencl, rocm-hip, akmod-nvidia, xorg-x11-drv-nvidia-cuda, nvidia-container-toolkit, driverctl

## VIRTUALIZATION (01-virt.sh)

### KVM / QEMU / Libvirt
qemu-kvm, qemu-img, qemu-user-static, libvirt, libvirt-daemon, libvirt-daemon-kvm, libvirt-daemon-qemu, libvirt-client, libvirt-nss, libvirt-dbus, virt-install, virt-manager, virt-viewer, spice-gtk, virt-top

### Android
waydroid (LXC-based Android container, native Wayland windows)

### VM Firmware & Security
edk2-ovmf, edk2-qosb, swtpm, swtpm-tools, dnsmasq, mdevctl, shim-x64, mokutil, sbsigntools, pesign, efitools

### Guest Image Tools
libguestfs, libguestfs-tools, guestfs-tools, nbdkit, libnbd

### Container Runtime
podman, podman-compose, podman-remote, buildah, skopeo, toolbox, distrobox, crun, netavark, aardvark-dns, slirp4netns, composefs

### Immutable OS / Image Building
bootc, bootc-image-builder, osbuild, osbuild-composer, osbuild-selinux, composer-cli, rpm-ostree

### Kubernetes
kubernetes-client, docker-compose, etcd, helm, k3s (binary), wireguard-tools

### Cockpit Web Management
cockpit, cockpit-system, cockpit-machines, cockpit-podman, cockpit-ostree, cockpit-storaged, cockpit-networkmanager, cockpit-selinux, cockpit-image-builder, pcp, cockpit-pcp, pcp-zeroconf, cockpit-benchmark (git), cockpit-zfs-manager (git)

### Gaming
gamemode, mangohud, gamescope, wine, winetricks, lutris, dosbox-staging, steam, steam-devices

### Guest Agents & Remote Access
hyperv-daemons, qemu-guest-agent, open-vm-tools, spice-vdagent, xrdp, xorgxrdp

### Storage & Networking
cifs-utils, virtiofsd, lvm2, mdadm, samba, nfs-utils, openssh-server, tailscale

### System Utilities
git, jq, make, curl, wget, nano, polkit, udisks2, clevis, lm_sensors, btop, nvtop, intel-gpu-tools

### Cloud / Deployment
cloud-init, rsync, tmux, screen, tree

### Network Diagnostics
socat, nmap-ncat, tcpdump, iptables-nft, conntrack-tools

### Storage Fabric (SAN/NAS)
nvme-cli, device-mapper-multipath, sg3_utils

### Time / Firewall / Swap
chrony, firewalld, zram-generator

### ISO / Image Tools
cdrkit, xorriso, genisoimage, isomd5sum, mediawriter, squashfs-tools, erofs-utils, dracut-live

### Python Development
python3-devel, python3-pip, python3-setuptools, python3-wheel, python3-virtualenv, python3-venv, python3-requests, python3-yaml, python3-toml, python3-jsonschema, python3-pillow, python3-tqdm, python3-rich, python3-click, python3-pytest, python3-black, python3-mypy, python3-ruff

## SECURITY & IPS

| Package | Description |
|---------|-------------|
| fapolicyd | Blocks untrusted binaries in /var/home |
| usbguard | USB device authorization |
| crowdsec | Collaborative IPS (log-based IP banning) |
| crowdsec-firewall-bouncer-nftables | CrowdSec nftables enforcement |
| firewalld | Default-deny drop zone firewall |
| scan-malware alias | On-demand containerized ClamAV |

## HIGH AVAILABILITY / CLUSTERING

### Cluster
corosync, pacemaker, pcs, fence-agents-all, resource-agents, keepalived, haproxy

### Storage Locking
sanlock, libvirt-lock-sanlock

### Distributed Storage
iscsi-initiator-utils, targetcli, ceph-common, glusterfs, glusterfs-server, glusterfs-fuse, glusterfs-cli

## LOOKING GLASS (Built from Source)
looking-glass-client (B7), 99-kvmfr.rules, 10-looking-glass.conf, looking-glass-start helper

Build deps removed after compile: cmake, gcc, gcc-c++, ~22 -devel packages

## TUNED POWER MANAGEMENT
tuned, tuned-ppd, tuned-utils, tuned-profiles-cpu-partitioning, tuned-profiles-realtime

## CUSTOM TOOLS
cloudws-rebuild, cloudws-vfio-toggle, cloudws-cockpit.desktop, cloudws-hostname.service, cloudws-init.service, cloudws-firewall-init

## CONFIGURATION FILES
/etc/environment.d/50-cloudws.conf, /etc/gtk-3.0/settings.ini, /etc/gtk-4.0/settings.ini, /usr/share/xdg-desktop-portal/gnome-portals.conf, /etc/dconf/db/local.d/01-cloudws, /etc/modprobe.d/nvidia.conf, /etc/modprobe.d/blacklist-nouveau.conf, /usr/lib/systemd/zram-generator.conf.d/cloudws.conf, /etc/sysctl.d/99-cloudws-vmhost.conf, /etc/multipath.conf, /etc/cloud/cloud.cfg.d/99-cloudws.cfg, /etc/libvirt/qemu.conf.d/10-cloudws.conf, /usr/lib/bootc/install/00-cloudws.toml, /etc/locale.conf, /usr/libexec/cloudws-firewall-init

## TOTALS

| Category | Count |
|----------|-------|
| RPM Packages (explicit) | ~210 |
| Flatpak Apps (baked) | 5 |
| Flatpak Runtimes (auto) | ~5 |
| Git-cloned plugins | 3 |
| Binary installs | 1 (K3s) |
| Custom tools | 6 |
| Config files | 15 |
