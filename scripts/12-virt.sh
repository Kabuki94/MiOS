#!/bin/bash
# CloudWS v0.1.1 — 12-virt: Virtualization, containers, orchestration, gaming
#
# CHANGELOG v1.3:
#   - Looking Glass B7: Added -DENABLE_LIBDECOR=ON for GNOME Wayland
#   - Looking Glass: Force OpenGL renderer config (fixes NVIDIA+Wayland flicker)
#   - K3s: MOVED to 13-ceph-k3s.sh (no longer duplicated here)
#   - CrowdSec: Updated sovereign mode config (RE2 regex engine default)
#   - Added Podman quadlet example for CrowdSec
#   - VirtIO-Win ISO: Updated URL pattern
#   - dkms excluded: conflicts with kernel-devel-matched on mixed kernel builds
#   - KVMFR built manually with make instead of dkms
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

KVER=$(cat /tmp/cloudws-kver 2>/dev/null || ls -1 /lib/modules/ | sort -V | tail -1)

# ── KVM / QEMU / Libvirt ────────────────────────────────────────────────────
echo "[12-virt] Installing KVM/QEMU/Libvirt..."
install_packages_strict "virt"

# ── Containers (Podman, Buildah, Skopeo, bootc) ─────────────────────────────
echo "[12-virt] Installing container runtime..."
install_packages_strict "containers"

# ── Cockpit Web Management ──────────────────────────────────────────────────
echo "[12-virt] Installing Cockpit..."
install_packages "cockpit"

# Cockpit plugins from git (machines, podman extended features)
echo "[12-virt] Building Cockpit plugins..."
install_packages "cockpit-plugins-build"
for plugin in cockpit-machines cockpit-podman; do
    if [ -d "/tmp/$plugin" ]; then
        cd "/tmp/$plugin" && make install 2>/dev/null || true
        cd /
    fi
done

# ── CrowdSec IPS (sovereign/offline mode) ───────────────────────────────────
echo "[12-virt] Installing CrowdSec..."
install_packages "security"

# Sovereign mode: disable Central API, use local-only decisions
if [ -d /etc/crowdsec ]; then
    mkdir -p /etc/crowdsec/acquis.d
    cat > /etc/crowdsec/acquis.d/journalctl.yaml <<'EOACQ'
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=sshd.service"
  - "_SYSTEMD_UNIT=nginx.service"
  - "_SYSTEMD_UNIT=httpd.service"
labels:
  type: syslog
EOACQ

    # Disable online API for sovereign operation
    if [ -f /etc/crowdsec/config.yaml ]; then
        sed -i 's/^online_client:/# online_client:/' /etc/crowdsec/config.yaml 2>/dev/null || true
    fi
    echo "[12-virt] CrowdSec configured for sovereign/offline mode"
fi

# ── Windows Interop & Remote Desktop ────────────────────────────────────────
echo "[12-virt] Installing Windows interop tools..."
install_packages "wintools"

# ── Gaming (Steam, Wine, Gamescope) ─────────────────────────────────────────
# NOTE: steam-devices and udev-joystick-blacklist-rm (terra weak dep of
# gamescope-session-steam) both ship the same udev rules file. Exclude it.
echo "[12-virt] Installing gaming packages..."
GAMING_PKGS=$(get_packages "gaming")
if [[ -n "$GAMING_PKGS" ]]; then
    dnf -y install --skip-unavailable --exclude=udev-joystick-blacklist-rm $GAMING_PKGS
fi

# ── Guest Agents ────────────────────────────────────────────────────────────
echo "[12-virt] Installing guest agents..."
install_packages "guests"

# ── Storage ─────────────────────────────────────────────────────────────────
echo "[12-virt] Installing storage packages..."
install_packages "storage"

# ── High Availability (Pacemaker/Corosync) ──────────────────────────────────
echo "[12-virt] Installing HA stack..."
install_packages "ha"

# ── CLI Utilities ───────────────────────────────────────────────────────────
echo "[12-virt] Installing CLI utilities..."
install_packages "utils"

# ── Android (Waydroid) ──────────────────────────────────────────────────────
echo "[12-virt] Installing Waydroid..."
install_packages "android"

# ── xRDP vsock for Hyper-V Enhanced Session ─────────────────────────────────
echo "[12-virt] Configuring xRDP vsock..."
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/^port=.*/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi

# ── VirtIO-Win ISO (latest stable) ─────────────────────────────────────────
echo "[12-virt] Downloading VirtIO-Win ISO..."
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
mkdir -p /var/lib/libvirt/images
curl -sL "$VIRTIO_URL" -o /var/lib/libvirt/images/virtio-win.iso 2>/dev/null || {
    echo "[12-virt] WARNING: VirtIO-Win ISO download failed — download manually later"
}

# ── Looking Glass B7 (compile from source) ──────────────────────────────────
echo "[12-virt] Building Looking Glass B7..."
# Exclude dkms: it requires kernel-devel-matched which conflicts when the
# base kernel doesn't match the fc44 repos. KVMFR is built manually below.
LG_BUILD_PKGS=$(get_packages "looking-glass-build")
if [[ -n "$LG_BUILD_PKGS" ]]; then
    dnf -y install --skip-unavailable --exclude=dkms $LG_BUILD_PKGS
fi

LG_VERSION="B7"
mkdir -p /tmp/looking-glass-build
cd /tmp/looking-glass-build

git clone --depth=1 --recurse-submodules --branch "${LG_VERSION}" \
    https://github.com/gnif/LookingGlass.git 2>/dev/null || true

if [ -d LookingGlass ]; then
    cd LookingGlass
    mkdir -p client/build host/build

    # Build client with libdecor (required for GNOME Wayland window decorations)
    cd client/build
    cmake \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DENABLE_LIBDECOR=ON \
        -DENABLE_PIPEWIRE=ON \
        -DENABLE_PULSEAUDIO=OFF \
        .. 2>/dev/null || true
    make -j"$(nproc)" 2>/dev/null || true
    if [ -f looking-glass-client ]; then
        install -m 755 looking-glass-client /usr/bin/looking-glass-client
        echo "[12-virt] Looking Glass client installed"
    fi

    # Build KVMFR kernel module manually (no dkms — avoids kernel-devel-matched conflict)
    cd /tmp/looking-glass-build/LookingGlass/module
    if [ -f Makefile ] && [ -d "/lib/modules/$KVER/build" ]; then
        echo "[12-virt] Building KVMFR module for kernel $KVER..."
        make KVER="$KVER" 2>/dev/null || true
        if [ -f kvmfr.ko ]; then
            install -D -m 644 kvmfr.ko "/lib/modules/$KVER/extra/kvmfr.ko"
            depmod -a "$KVER" 2>/dev/null || true
            echo "[12-virt] KVMFR module installed for $KVER"
        else
            echo "[12-virt] WARNING: KVMFR module build failed — Looking Glass IVSHMEM-only"
        fi
    elif [ -f dkms.conf ]; then
        # Fallback: try dkms if it happens to be installed
        mkdir -p /usr/src/kvmfr-0.0.1
        cp -a . /usr/src/kvmfr-0.0.1/
        dkms add kvmfr/0.0.1 2>/dev/null || true
        dkms build kvmfr/0.0.1 -k "$KVER" 2>/dev/null || true
        dkms install kvmfr/0.0.1 -k "$KVER" 2>/dev/null || true
    fi

    cd /
fi

# Looking Glass config: Force OpenGL renderer (fixes NVIDIA+Wayland flicker)
mkdir -p /etc/skel/.config/looking-glass
cat > /etc/skel/.config/looking-glass/client.ini <<'EOLGCFG'
[app]
renderer=opengl

[win]
fullScreen=no
maximize=no

[input]
grabKeyboardOnFocus=yes
escapeKey=KEY_RIGHTCTRL
EOLGCFG

# KVMFR module config
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/kvmfr.conf <<'EOKVMFR'
# CloudWS: KVMFR shared memory for Looking Glass
# 128MB sufficient for 4K SDR. Increase for ultrawide or HDR.
options kvmfr static_size_mb=128
EOKVMFR

# Clean up build deps (keep binary, remove sources)
rm -rf /tmp/looking-glass-build

# Remove build-only packages to shrink image
echo "[12-virt] Removing Looking Glass build dependencies..."
BUILD_DEPS=$(get_packages "looking-glass-build" 2>/dev/null || echo "")
if [ -n "$BUILD_DEPS" ]; then
    # Only remove packages that are truly build-only (cmake, *-devel)
    for pkg in cmake gcc gcc-c++ libglvnd-devel fontconfig-devel; do
        dnf remove -y "$pkg" --noautoremove 2>/dev/null || true
    done
fi

# ── Podman Quadlet: CrowdSec (example pattern for containerized services) ───
# This is the recommended pattern for managing services on bootc images.
# Placed in /usr/share/containers/systemd/ (immutable, baked into image).
mkdir -p /usr/share/containers/systemd
cat > /usr/share/containers/systemd/crowdsec-dashboard.container <<'EOQUAD'
# CloudWS v0.1.1 — Example Podman quadlet for CrowdSec dashboard
# To enable: symlink from /etc/containers/systemd/ or systemctl enable
[Container]
Image=docker.io/crowdsecurity/metabase:latest
ContainerName=crowdsec-dashboard
PublishPort=3000:3000
Volume=crowdsec-data.volume:/metabase-data
AutoUpdate=registry

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOQUAD

# ── CrowdSec data volume (required by crowdsec-dashboard.container quadlet) ──
cat > /usr/share/containers/systemd/crowdsec-data.volume <<'EOVOL'
[Volume]
# CloudWS v2.0: Persistent storage for CrowdSec Metabase dashboard
EOVOL

echo "[12-virt] Virtualization stack complete. LG: ${LG_VERSION} (K3s in 13-ceph-k3s.sh)"
