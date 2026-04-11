#!/bin/bash
# CloudWS v2.0 — 38-vm-gating: VM-specific service gating, Hyper-V, xRDP
#
# Hyper-V Enhanced Session strategy:
#   - GDM runs natively on the console (user sees normal GNOME login)
#   - gnome-remote-desktop provides RDP AFTER login (no xrdp login screen)
#   - xRDP is available as fallback but configured to launch gnome-session
#     directly (no xrdp login dialog when connecting via Enhanced Session)
#   - Enhanced session auto-configures on Hyper-V VMs only
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

# ═══ HYPER-V ENHANCED SESSION ═══
echo "[38-vm-gating] Installing Hyper-V Enhanced Session service..."

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

# Key fix: Enhanced session starts AFTER GDM, and xrdp is configured
# to use vsock transport so Hyper-V can use it alongside the native console.
# gnome-remote-desktop (GRD) is the PRIMARY RDP provider — it shares the
# existing GNOME session (no separate login). xRDP is the FALLBACK for
# when GRD isn't running yet.
cat > /usr/libexec/cloudws-hyperv-enhanced <<'EOHV'
#!/bin/bash
set -euo pipefail
echo "[cloudws-hyperv] Configuring Enhanced Session (vsock)..."

# Configure xRDP for vsock transport (Hyper-V Enhanced Session)
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/^use_vsock=.*/use_vsock=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    sed -i 's/^bitmap_compression=.*/bitmap_compression=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    # Set port to support both vsock and TCP
    sed -i 's/^port=.*/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini 2>/dev/null || true
fi

# Configure sesman for auto-login (skip xrdp login screen)
if [ -f /etc/xrdp/sesman.ini ]; then
    sed -i 's/^MaxSessions=.*/MaxSessions=10/' /etc/xrdp/sesman.ini 2>/dev/null || true
    sed -i 's/^KillDisconnected=.*/KillDisconnected=false/' /etc/xrdp/sesman.ini 2>/dev/null || true
fi

systemctl enable --now xrdp xrdp-sesman 2>/dev/null || true
echo "[cloudws-hyperv] Enhanced Session ready (GDM-first, xRDP fallback on vsock)"
EOHV
chmod +x /usr/libexec/cloudws-hyperv-enhanced
systemctl enable cloudws-hyperv-enhanced.service 2>/dev/null || true

# ═══ xRDP session launcher — launches GNOME directly ═══
echo "[38-vm-gating] Fixing xRDP session launcher..."
if [ -d /etc/xrdp ]; then
    cat > /etc/xrdp/startwm.sh <<'EOXRDP'
#!/bin/sh
# CloudWS v2.0: xRDP session launcher
# Launches GNOME session directly (X11 fallback for xRDP compatibility)
if [ -r /etc/profile ]; then . /etc/profile; fi
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export GNOME_SHELL_SESSION_MODE=gnome
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24
export GTK_THEME=adw-gtk3-dark
export ADW_DEBUG_COLOR_SCHEME=prefer-dark
exec gnome-session
EOXRDP
    chmod +x /etc/xrdp/startwm.sh
fi

# ═══ GNOME Remote Desktop — first-boot setup ═══
echo "[38-vm-gating] Installing gnome-remote-desktop first-boot setup..."
cp /tmp/build/scripts/cloudws-grd-setup /usr/libexec/cloudws-grd-setup 2>/dev/null || true
chmod +x /usr/libexec/cloudws-grd-setup 2>/dev/null || true
systemctl enable cloudws-grd-setup.service 2>/dev/null || true

echo "[38-vm-gating] VM gating + Hyper-V enhanced session configured."
