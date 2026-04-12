#!/bin/bash
# CloudWS v2.0.2 — 38-vm-gating: VM service gating + Hyper-V Enhanced Session
#
# ENHANCED SESSION FIX:
#   Root cause: xrdp.ini defaults to [Xvnc] which fails with "VNC error -
#   no IP set for TCP connection" because vsock transport doesn't work with
#   the VNC backend. Fix: use xorgxrdp (Xorg backend via libxup.so) and
#   make [Xorg] the FIRST session in xrdp.ini so it's the default.
#
#   Required: xorgxrdp package, hv_sock module, vmw_vsock blacklist,
#   Xwrapper.config allowing anybody, polkit rules for color-manager.
set -euo pipefail

echo "[38-vm-gating] Configuring VM-specific service gating..."

# ═══ GDM: only skip in WSL2 (Hyper-V VMs SHOULD run GDM) ═══
mkdir -p /usr/lib/systemd/system/gdm.service.d
cat > /usr/lib/systemd/system/gdm.service.d/10-skip-wsl.conf <<'DROPIN'
[Unit]
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN

# ═══ nvidia-powerd: skip in ALL VMs ═══
if [ -f /usr/lib/systemd/system/nvidia-powerd.service ]; then
    mkdir -p /usr/lib/systemd/system/nvidia-powerd.service.d
    cat > /usr/lib/systemd/system/nvidia-powerd.service.d/10-bare-metal-only.conf <<'DROPIN'
[Unit]
ConditionVirtualization=no
DROPIN
fi

# ═══ Waydroid + binder: skip in WSL2 ═══
for svc in waydroid-container dev-binderfs.mount; do
    if [ -f "/usr/lib/systemd/system/${svc}" ] || [ -f "/usr/lib/systemd/system/${svc}.service" ]; then
        unit="${svc}"
        [[ "$unit" != *.* ]] && unit="${unit}.service"
        mkdir -p "/usr/lib/systemd/system/${unit}.d"
        cat > "/usr/lib/systemd/system/${unit}.d/10-skip-wsl.conf" <<'DROPIN'
[Unit]
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN
    fi
done

# ═══ Mask serial console everywhere ═══
systemctl mask serial-getty@ttyS0.service 2>/dev/null || true

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
# HYPER-V ENHANCED SESSION — COMPLETE WORKING CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════
echo "[38-vm-gating] Configuring Hyper-V Enhanced Session (xorgxrdp)..."

# 1. Blacklist VMware vsock (conflicts with Hyper-V hv_sock)
cat > /etc/modprobe.d/blacklist-vmw_vsock.conf <<'EOMOD'
blacklist vmw_vsock_vmci_transport
EOMOD

# 2. Ensure hv_sock loads on boot
if ! grep -q 'hv_sock' /etc/modules-load.d/cloudws.conf 2>/dev/null; then
    echo "hv_sock" >> /etc/modules-load.d/cloudws.conf
fi

# 3. Allow any user to start X server (required for xorgxrdp)
mkdir -p /etc/X11
cat > /etc/X11/Xwrapper.config <<'EOXWRAP'
allowed_users=anybody
needs_root_rights=yes
EOXWRAP

# 4. Polkit rule for colord (prevents "not authorized" errors in xRDP sessions)
mkdir -p /etc/polkit-1/localauthority/50-local.d 2>/dev/null || true
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

# 5. Write the COMPLETE xrdp.ini — Xorg FIRST (default), Xvnc disabled
echo "[38-vm-gating] Writing xrdp.ini with Xorg as default session..."
if [ -f /etc/xrdp/xrdp.ini ]; then
    # Back up original
    cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.orig 2>/dev/null || true

    # Set vsock transport
    sed -i 's/^port=.*/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini
    # Set security for local connection (fast)
    sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini
    sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini
    # Disable bitmap compression (better quality over local vsock)
    sed -i 's/^bitmap_compression=.*/bitmap_compression=false/' /etc/xrdp/xrdp.ini

    # Make Xorg the default by reordering: put [Xorg] before [Xvnc]
    # First ensure the Xorg section exists and is uncommented
    if ! grep -q '^\[Xorg\]' /etc/xrdp/xrdp.ini; then
        # Xorg section doesn't exist — add it before Xvnc
        sed -i '/^\[Xvnc\]/i \[Xorg\]\nname=Xorg\nlib=libxup.so\nusername=ask\npassword=ask\nip=127.0.0.1\nport=-1\ncode=20\n' /etc/xrdp/xrdp.ini
    fi

    # Comment out the entire Xvnc section so only Xorg is available
    sed -i '/^\[Xvnc\]/,/^\[/ { /^\[Xvnc\]/s/^/;/; /^\[/!s/^/;/ }' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi

# 6. sesman.ini — shared drives + session limits
if [ -f /etc/xrdp/sesman.ini ]; then
    sed -i 's/^MaxSessions=.*/MaxSessions=10/' /etc/xrdp/sesman.ini 2>/dev/null || true
    sed -i 's/^KillDisconnected=.*/KillDisconnected=false/' /etc/xrdp/sesman.ini 2>/dev/null || true
    sed -i 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/' /etc/xrdp/sesman.ini 2>/dev/null || true
fi

# 7. startwm.sh — launch GNOME session with proper environment
echo "[38-vm-gating] Writing xRDP session launcher..."
if [ -d /etc/xrdp ]; then
    cat > /etc/xrdp/startwm.sh <<'EOXRDP'
#!/bin/sh
# CloudWS v2.0.2: xRDP session launcher for GNOME on Xorg
# This runs when a user logs in via xRDP (enhanced session or network RDP)
if [ -r /etc/profile ]; then . /etc/profile; fi

# Session type must be X11 (xorgxrdp provides the X server)
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export GNOME_SHELL_SESSION_MODE=gnome

# Cursor theme
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24

# Dark theme
export GTK_THEME=adw-gtk3-dark
export ADW_DEBUG_COLOR_SCHEME=prefer-dark

# D-Bus (required for GNOME session)
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Launch GNOME on Xorg
exec gnome-session --session=gnome
EOXRDP
    chmod +x /etc/xrdp/startwm.sh
fi

# 8. Hyper-V enhanced session auto-enable service
cat > /usr/lib/systemd/system/cloudws-hyperv-enhanced.service <<'EOSVC'
[Unit]
Description=CloudWS Hyper-V Enhanced Session Setup
After=local-fs.target network.target gdm.service
ConditionVirtualization=microsoft

[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-hyperv-enhanced
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOSVC

cat > /usr/libexec/cloudws-hyperv-enhanced <<'EOHV'
#!/bin/bash
set -euo pipefail
echo "[cloudws-hyperv] Configuring Enhanced Session..."

# Load hv_sock module
modprobe hv_sock 2>/dev/null || true

# Ensure xrdp is running
systemctl enable --now xrdp xrdp-sesman 2>/dev/null || true

echo "[cloudws-hyperv] Enhanced Session ready (Xorg backend via xorgxrdp)"
EOHV
chmod +x /usr/libexec/cloudws-hyperv-enhanced
systemctl enable cloudws-hyperv-enhanced.service 2>/dev/null || true

# ═══ GNOME Remote Desktop — first-boot setup ═══
echo "[38-vm-gating] Installing gnome-remote-desktop first-boot setup..."
cp /tmp/build/scripts/cloudws-grd-setup /usr/libexec/cloudws-grd-setup 2>/dev/null || true
chmod +x /usr/libexec/cloudws-grd-setup 2>/dev/null || true
systemctl enable cloudws-grd-setup.service 2>/dev/null || true

echo "[38-vm-gating] VM gating + Hyper-V enhanced session (xorgxrdp) configured."
