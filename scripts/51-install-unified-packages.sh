#!/usr/bin/bash
# 51-install-unified-packages.sh - install EVERY package from
# PACKAGES-UNIFIED-EXTRAS.md in one transaction. Baked-in principle.
#
# Packages are grouped by section. A failure in one group does NOT stop the
# others - each dnf5 call is independent. At the end, a summary reports
# which groups succeeded/failed.
set -uo pipefail

log() { printf '[51-install] %s\n' "$*"; }
fail_groups=()

try_install() {
    local group="$1"; shift
    log "==> installing group: $group"
    if dnf5 -y install --setopt=install_weak_deps=False "$@"; then
        log "    OK: $group"
    else
        log "    FAIL: $group"
        fail_groups+=("$group")
    fi
}

# --- Build infrastructure (self-building principle) ------------------------
try_install "build-infra" \
    bootc bootc-image-builder ostree skopeo buildah cosign just \
    git make cmake gcc gcc-c++ pkgconf-pkg-config meson ninja-build \
    rust cargo

# --- Machine-backend scaffolding (some already installed in 44) ------------
try_install "machine-backend" \
    cloud-init qemu-guest-agent spice-vdagent wslu python3-pip

# --- Security / supply chain -----------------------------------------------
try_install "security" \
    usbguard audit aide openscap-scanner scap-security-guide \
    libpwquality policycoreutils policycoreutils-python-utils setools-console \
    nftables firewalld

# --- CrowdSec (from packagecloud, set up in 50) ----------------------------
try_install "crowdsec" \
    crowdsec crowdsec-firewall-bouncer-nftables

# --- Container / Kubernetes runtime ----------------------------------------
try_install "k8s-runtime" \
    podman podman-plugins podman-docker containers-common \
    toolbox distrobox kubectl helm
# k3s itself: binary install via official script at first boot (for agent
# and server roles). Ship the installer script + SELinux policy.
log "==> installing k3s binary via upstream installer"
curl -fsSL https://get.k3s.io -o /usr/local/bin/k3s-install.sh && \
    chmod +x /usr/local/bin/k3s-install.sh || \
    log "WARN: k3s installer download failed"
# Pre-download the k3s binary itself so first boot doesn't need network
curl -fsSL https://github.com/k3s-io/k3s/releases/latest/download/k3s -o /usr/local/bin/k3s && \
    chmod +x /usr/local/bin/k3s || \
    log "WARN: k3s binary download failed"

# --- NVIDIA toolkit (kmod already from ucore-hci) --------------------------
try_install "nvidia-userspace" \
    nvidia-container-toolkit nvidia-container-toolkit-base \
    nvidia-container-selinux libnvidia-container-tools

# --- Virtualization / VFIO -------------------------------------------------
try_install "virtualization" \
    libvirt libvirt-daemon-kvm libvirt-dbus \
    qemu-kvm qemu-device-display-virtio-gpu \
    edk2-ovmf swtpm swtpm-tools \
    virt-install virt-viewer virt-manager libguestfs-tools \
    dnsmasq \
    cockpit cockpit-machines cockpit-storaged cockpit-networkmanager cockpit-podman

# --- HA + storage (Ceph, Pacemaker, Corosync) ------------------------------
try_install "ha-storage" \
    pacemaker corosync pcs fence-agents-all resource-agents sbd \
    ceph-common

# --- Updater (greenboot already in 46; uupd in 43) -------------------------
try_install "updater" \
    greenboot greenboot-default-health-checks

# --- Desktop / Wayland -----------------------------------------------------
try_install "desktop" \
    gnome-shell gnome-session-wayland-session gnome-session-xsession \
    gdm gnome-control-center gnome-remote-desktop \
    freerdp freerdp-libs \
    pipewire pipewire-pulseaudio wireplumber \
    xdg-desktop-portal xdg-desktop-portal-gnome libei

# --- Gaming (Gamescope session + Steam) ------------------------------------
try_install "gaming" \
    gamescope steam steam-devices mangohud gamemode

# --- Waydroid (Android-in-Linux runtime) -----------------------------------
try_install "waydroid" \
    waydroid

# --- Build dependencies for baked-in compiles (kvmfr, Looking Glass) -------
# These are needed by 52-bake-kvmfr.sh and 53-bake-lookingglass-client.sh.
# Installed here so they're present before those scripts run.
try_install "lg-build-deps" \
    kernel-devel kernel-headers dkms elfutils-libelf-devel \
    spice-protocol \
    fontconfig-devel freetype-devel \
    libX11-devel libXScrnSaver-devel libXi-devel libXinerama-devel \
    libxkbcommon-x11-devel \
    wayland-devel wayland-protocols-devel \
    nettle-devel \
    SDL2-devel libsamplerate-devel \
    mesa-libGL-devel mesa-libEGL-devel \
    libdecor-devel \
    pulseaudio-libs-devel

# PipeWire-devel separately (sometimes fails in rawhide)
try_install "pipewire-devel" pipewire-devel

# --- AMD/Intel GPU compute (user principle: support all GPU vendors) -------
try_install "amd-compute" \
    mesa-vulkan-drivers rocm-runtime rocm-smi rocminfo || true
try_install "intel-compute" \
    intel-compute-runtime intel-media-driver intel-ocloc || true

# --- Summary ---------------------------------------------------------------
if ((${#fail_groups[@]} == 0)); then
    log "ALL GROUPS INSTALLED SUCCESSFULLY"
else
    log "WARN: ${#fail_groups[@]} group(s) failed: ${fail_groups[*]}"
    log "      Build continues - failures are non-fatal in this script."
    log "      Check journalctl on first boot to identify missing capability."
fi

exit 0