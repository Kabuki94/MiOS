#!/bin/bash
# CloudWS v2.1.1 — 38-vm-gating: VM service gating + Hyper-V Enhanced Session
#
# v2.1.1 CRITICAL FIX: GNOME 50 / Mutter 50 completely removed the X11 backend.
# xorgxrdp is an X11 technology — it CANNOT work with Wayland-only Mutter 50.
# The old approach caused a GDM crash loop on Hyper-V, preventing boot.
#
# NEW APPROACH: Use gnome-remote-desktop (GRD) for Enhanced Session.
# GRD provides Wayland-native RDP and can bind to vsock for Hyper-V transport.
# xrdp is kept installed but NOT auto-enabled — it's available as a manual
# fallback for non-GNOME sessions (XFCE, Phosh) only.
#
# HYPER-V BOOT PATH (without Enhanced Session):
#   hyperv_drm → KMS → GDM (Wayland) → llvmpipe software rendering → login
# HYPER-V ENHANCED SESSION PATH:
#   vmconnect → vsock:3389 → gnome-remote-desktop (Wayland RDP) → login
set -euo pipefail

echo "[38-vm-gating] Configuring VM-specific service gating..."

# ═══ GDM / nvidia-powerd / Waydroid + binder gating ═══
# Drop-ins for gdm, nvidia-powerd, waydroid-container, dev-binderfs.mount are
# created by 20-services.sh (WSL_SKIP_SERVICES + bare-metal nvidia-powerd block).
# Do NOT duplicate them here — last writer wins and we want 20's canonical drop-ins.

# ═══ Polkit container workaround ═══
mkdir -p /usr/lib/systemd/system/polkit.service.d
cat > /usr/lib/systemd/system/polkit.service.d/10-cloudws-container.conf <<'DROPIN'
[Unit]
StartLimitIntervalSec=300
StartLimitBurst=3

[Service]
Restart=on-failure
RestartSec=30
DROPIN

# ═══ Cockpit socket drop-in permissions ═══
if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    chmod 644 /etc/systemd/system/cockpit.socket.d/listen.conf
fi

# ═══════════════════════════════════════════════════════════════════════════
# HYPER-V ENHANCED SESSION — WAYLAND-NATIVE VIA GNOME REMOTE DESKTOP
# ═══════════════════════════════════════════════════════════════════════════
echo "[38-vm-gating] Configuring Hyper-V Enhanced Session (gnome-remote-desktop)..."

# 1. Blacklist VMware vsock (conflicts with Hyper-V hv_sock)
cat > /etc/modprobe.d/blacklist-vmw_vsock.conf <<'EOMOD'
blacklist vmw_vsock_vmci_transport
EOMOD

# 2. Ensure hv_sock loads on boot (required for vsock RDP transport)
if ! grep -q 'hv_sock' /etc/modules-load.d/cloudws.conf 2>/dev/null; then
    echo "hv_sock" >> /etc/modules-load.d/cloudws.conf
fi

# 3. Polkit rule for colord (prevents "not authorized" errors in RDP sessions)
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/45-allow-colord.rules <<'EOPOLKIT'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.color-manager.create-device" ||
         action.id == "org.freedesktop.color-manager.create-profile" ||
         action.id == "org.freedesktop.color-manager.delete-device" ||
         action.id == "org.freedesktop.color-manager.delete-profile" ||
         action.id == "org.freedesktop.color-manager.modify-device" ||
         action.id == "org.freedesktop.color-manager.modify-profile") &&
        subject.isInGroup("{users}")) {
        return polkit.Result.YES;
    }
});
EOPOLKIT

# 4. Hyper-V Enhanced Session service — uses gnome-remote-desktop (NOT xrdp)
# GRD provides Wayland-native RDP. On Hyper-V, it listens on vsock or TCP 3389.
cat > /usr/lib/systemd/system/cloudws-hyperv-enhanced.service <<'EOSVC'
[Unit]
Description=CloudWS Hyper-V Enhanced Session Setup (gnome-remote-desktop)
After=local-fs.target network.target gdm.service
ConditionVirtualization=microsoft

[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-hyperv-enhanced
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOSVC

cat > /usr/libexec/cloudws-hyperv-enhanced <<'EOHV'
#!/bin/bash
set -euo pipefail
echo "[cloudws-hyperv] Configuring Enhanced Session via gnome-remote-desktop..."

# Load hv_sock module for vsock transport
modprobe hv_sock 2>/dev/null || true

# Enable gnome-remote-desktop system service (Wayland RDP)
# The cloudws-grd-setup.service handles TLS cert generation and credentials.
systemctl enable --now gnome-remote-desktop.service 2>/dev/null || true

# Open firewall for RDP
if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=3389/tcp 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
fi

# Ensure NVIDIA modules don't probe in Hyper-V (no physical GPU)
# This prevents module load delays and error messages
if [ ! -d /sys/bus/pci/drivers/nvidia ]; then
    echo "blacklist nvidia" > /etc/modprobe.d/cloudws-hyperv-nvidia.conf 2>/dev/null || true
    echo "blacklist nvidia_drm" >> /etc/modprobe.d/cloudws-hyperv-nvidia.conf 2>/dev/null || true
    echo "blacklist nvidia_modeset" >> /etc/modprobe.d/cloudws-hyperv-nvidia.conf 2>/dev/null || true
    echo "blacklist nvidia_uvm" >> /etc/modprobe.d/cloudws-hyperv-nvidia.conf 2>/dev/null || true
fi

echo "[cloudws-hyperv] Enhanced Session ready (Wayland RDP via gnome-remote-desktop)"
EOHV
chmod +x /usr/libexec/cloudws-hyperv-enhanced
systemctl enable cloudws-hyperv-enhanced.service 2>/dev/null || true

# 5. xrdp: configure but do NOT auto-enable globally
# xrdp stays installed for manual use with non-GNOME sessions (Phosh, XFCE).
# For GNOME 50, gnome-remote-desktop is the only working RDP path.
if [ -f /etc/xrdp/xrdp.ini ]; then
    echo "[38-vm-gating] Configuring xrdp (available, not auto-started)..."
    cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.orig 2>/dev/null || true
    # Set vsock transport for Hyper-V
    sed -i 's/^port=.*/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini
    sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini
    sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini

    # Allow any user to start X server (for non-GNOME xorgxrdp sessions)
    mkdir -p /etc/X11
    cat > /etc/X11/Xwrapper.config <<'EOXWRAP'
allowed_users=anybody
needs_root_rights=yes
EOXWRAP
fi

# 6. GNOME Remote Desktop — first-boot setup script
# cloudws-grd-setup is installed via system_files overlay (08-system-files-overlay.sh)
# into /usr/libexec/cloudws-grd-setup. No copy needed here.
chmod +x /usr/libexec/cloudws-grd-setup 2>/dev/null || true

# ── WSL2 systemd-machined gating ─────────────────────────────────────────
# dbus-broker.service.d/wsl2-fix.conf is provided by system_files overlay
# (OOMScoreAdjust only; --audit removal is in 10-cloudws-no-audit.conf).
# Do NOT overwrite it here — previous versions wrote a broken drop-in with
# ConditionPathExists=|/proc/version which is always true and caused dbus
# to be misconfigured on bare metal.

# Ensure systemd-machined doesn't block dbus in WSL2
mkdir -p /etc/systemd/system/systemd-machined.service.d
cat > /etc/systemd/system/systemd-machined.service.d/wsl2-optional.conf <<'MACHINEDFIX'
[Unit]
# Make machined non-fatal in WSL2 (it needs cgroup features WSL2 lacks)
ConditionVirtualization=!wsl
MACHINEDFIX

echo "[38-vm-gating] VM gating + Hyper-V Enhanced Session (gnome-remote-desktop) configured."
