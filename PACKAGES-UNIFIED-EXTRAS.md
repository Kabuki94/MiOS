# CloudWS-bootc v2.2.0 - Unified Image Package Extras

This file lists packages added in v2.2.0 for the unified-image / role-switched
architecture. The build pipeline parses both PACKAGES.md and PACKAGES-UNIFIED-EXTRAS.md.

## Build infrastructure

```
bootc
bootc-image-builder
cosign
just
skopeo
buildah
```

## Machine-backend scaffolding

```
openssh-server
openssh-clients
sudo
polkit
cloud-init
qemu-guest-agent
spice-vdagent
wslu
python3-pip
```

## Security / supply chain

```
crowdsec
crowdsec-firewall-bouncer-nftables
nftables
firewalld
usbguard
audit
aide
openscap-scanner
scap-security-guide
libpwquality
policycoreutils
policycoreutils-python-utils
setools-console
```

## Container / Kubernetes runtime

```
podman
podman-plugins
podman-docker
containers-common
toolbox
distrobox
k3s
kubectl
helm
```

## NVIDIA stack (COPY --from=ublue-os akmods in Containerfile; these are the userspace deps)

```
nvidia-container-toolkit
nvidia-container-toolkit-base
nvidia-container-selinux
libnvidia-container-tools
```

## Virtualization / VFIO

```
libvirt
libvirt-daemon-kvm
libvirt-dbus
qemu-kvm
qemu-device-display-virtio-gpu
edk2-ovmf
swtpm
swtpm-tools
virt-install
virt-viewer
virt-manager
libguestfs-tools
dnsmasq
cockpit
cockpit-machines
cockpit-storaged
cockpit-networkmanager
cockpit-podman
```

## HA + storage (Ceph/Pacemaker)

```
pacemaker
corosync
pcs
fence-agents-all
resource-agents
sbd
ceph-common
ceph-base
```

## Updater

```
uupd
greenboot
greenboot-default-health-checks
```

## Desktop / Wayland

```
gnome-shell
gnome-session-wayland-session
gnome-session-xsession
gdm
gnome-control-center
gnome-remote-desktop
freerdp
freerdp-libs
pipewire
pipewire-pulseaudio
wireplumber
xdg-desktop-portal
xdg-desktop-portal-gnome
libei
```

## Gaming (Gamescope session + Steam; optional via FEATURES=gamescope)

```
gamescope
steam
steam-devices
mangohud
gamemode
```