#!/bin/bash
# CloudWS v0.1.8 — 38-vm-gating: VM service gating + Hyper-V Enhanced Session
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
# Managed via system_files/usr/lib/systemd/system/polkit.service.d/10-cloudws-container.conf

# ═══ Cockpit socket drop-in permissions ═══
if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    chmod 644 /etc/systemd/system/cockpit.socket.d/listen.conf
fi

# ═══════════════════════════════════════════════════════════════════════════
# HYPER-V ENHANCED SESSION — WAYLAND-NATIVE VIA GNOME REMOTE DESKTOP
# ═══════════════════════════════════════════════════════════════════════════
echo "[38-vm-gating] Configuring Hyper-V Enhanced Session (gnome-remote-desktop)..."

# 1. Blacklist VMware vsock (conflicts with Hyper-V hv_sock)
# Managed via system_files/etc/modprobe.d/blacklist-vmw_vsock.conf

# 2. Ensure hv_sock loads on boot (required for vsock RDP transport)
if ! grep -q 'hv_sock' /etc/modules-load.d/cloudws.conf 2>/dev/null; then
    echo "hv_sock" >> /etc/modules-load.d/cloudws.conf
fi

# 3. Polkit rule for colord (prevents "not authorized" errors in RDP sessions)
# Managed via system_files/etc/polkit-1/rules.d/45-allow-colord.rules

# 4. Hyper-V Enhanced Session service — uses gnome-remote-desktop (NOT xrdp)
# Managed via system_files/usr/lib/systemd/system/cloudws-hyperv-enhanced.service
# and system_files/usr/libexec/cloudws-hyperv-enhanced
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
    # Managed via system_files/etc/X11/Xwrapper.config
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
# Managed via system_files/usr/lib/systemd/system/systemd-machined.service.d/wsl2-optional.conf

echo "[38-vm-gating] VM gating + Hyper-V Enhanced Session (gnome-remote-desktop) configured."
