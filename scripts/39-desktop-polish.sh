#!/bin/bash
# CloudWS v2.0 — 39-desktop-polish: Desktop entries, Cockpit webapp, MOTD
set -euo pipefail

echo "[39-desktop-polish] Final desktop polish..."

# ═══ COCKPIT DESKTOP ENTRY — uses cockpit-desktop (no TLS warnings) ═══
echo "[39-desktop-polish] Creating Cockpit desktop entry..."
mkdir -p /usr/share/applications
cat > /usr/share/applications/cockpit.desktop <<'EODESKTOP'
[Desktop Entry]
Type=Application
Name=Cockpit Dashboard
Comment=CloudWS Server Management
Exec=cockpit-desktop /
Icon=cockpit
Categories=System;
Keywords=server;management;dashboard;
EODESKTOP

# Also create an Epiphany web app shortcut as fallback
cat > /usr/share/applications/cockpit-browser.desktop <<'EODESKTOP'
[Desktop Entry]
Type=Application
Name=Cockpit (Browser)
Comment=CloudWS Server Management (opens in browser)
Exec=xdg-open http://localhost:9090
Icon=cockpit
Categories=System;
NoDisplay=true
EODESKTOP

# ═══ NVIDIA SETTINGS DESKTOP ENTRY ═══
echo "[39-desktop-polish] Creating NVIDIA Settings desktop entry..."
cat > /usr/share/applications/nvidia-settings.desktop <<'EODESKTOP'
[Desktop Entry]
Type=Application
Name=NVIDIA Settings
Comment=NVIDIA GPU Configuration
Exec=nvidia-settings
Icon=nvidia-settings
Categories=System;Settings;
Keywords=nvidia;gpu;graphics;
EODESKTOP

# ═══ CEPH DASHBOARD — update to use correct app name ═══
cat > /usr/share/applications/ceph-dashboard.desktop <<'EODESKTOP'
[Desktop Entry]
Type=Application
Name=Ceph Dashboard
Comment=Ceph Storage Dashboard
Exec=xdg-open https://localhost:8443
Icon=drive-harddisk
Categories=System;
Keywords=ceph;storage;
EODESKTOP

# ═══ MOTD DASHBOARD ═══
echo "[39-desktop-polish] Installing CloudWS MOTD dashboard..."
cp /tmp/build/scripts/cloudws-motd /usr/libexec/cloudws-motd 2>/dev/null || true
chmod +x /usr/libexec/cloudws-motd 2>/dev/null || true

# ═══ FASTFETCH CONFIG — services dashboard on terminal open ═══
echo "[39-desktop-polish] Installing fastfetch system config..."
mkdir -p /etc/fastfetch
cat > /etc/fastfetch/config.jsonc <<'EOFF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "none"
    },
    "display": {
        "separator": "  ",
        "color": {
            "keys": "blue"
        }
    },
    "modules": [
        {
            "type": "custom",
            "format": "\u001b[36m════════════════════════════════════════════\u001b[0m"
        },
        {
            "type": "title",
            "format": "\u001b[1;37mCloudWS\u001b[0m  \u001b[90m{2}@{1}\u001b[0m"
        },
        {
            "type": "custom",
            "format": "\u001b[36m════════════════════════════════════════════\u001b[0m"
        },
        "break",
        {
            "type": "os",
            "key": "  OS"
        },
        {
            "type": "kernel",
            "key": "  Kernel"
        },
        {
            "type": "uptime",
            "key": "  Uptime"
        },
        {
            "type": "packages",
            "key": "  Packages"
        },
        {
            "type": "shell",
            "key": "  Shell"
        },
        {
            "type": "de",
            "key": "  Desktop"
        },
        "break",
        {
            "type": "cpu",
            "key": "  CPU"
        },
        {
            "type": "gpu",
            "key": "  GPU"
        },
        {
            "type": "memory",
            "key": "  Memory"
        },
        {
            "type": "disk",
            "key": "  Disk",
            "folders": "/"
        },
        "break",
        {
            "type": "custom",
            "format": "\u001b[36m── Services & Management ──────────────────\u001b[0m"
        },
        {
            "type": "command",
            "key": "  🔧 Cockpit",
            "keyColor": "green",
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -1); systemctl is-active --quiet cockpit.socket 2>/dev/null && echo \"✓ https://${IP:-localhost}:9090\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  🖥️  RDP",
            "keyColor": "green",
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -1); (systemctl is-active --quiet gnome-remote-desktop 2>/dev/null || systemctl is-active --quiet xrdp 2>/dev/null) && echo \"✓ rdp://${IP:-localhost}:3389\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  🔒 SSH",
            "keyColor": "green",
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -1); systemctl is-active --quiet sshd 2>/dev/null && echo \"✓ ssh://${IP:-localhost}:22\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  📦 Podman",
            "keyColor": "green",
            "text": "systemctl is-active --quiet podman.socket 2>/dev/null && echo \"✓ $(podman ps -q 2>/dev/null | wc -l) containers\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  🛡️  Firewall",
            "keyColor": "green",
            "text": "systemctl is-active --quiet firewalld 2>/dev/null && echo '✓ active' || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  ☸ K3s",
            "keyColor": "green",
            "text": "systemctl is-active --quiet k3s 2>/dev/null && echo '✓ https://localhost:6443' || echo '○ disabled'"
        },
        {
            "type": "command",
            "key": "  🗄️  Libvirt",
            "keyColor": "green",
            "text": "systemctl is-active --quiet libvirtd.socket 2>/dev/null && echo \"✓ $(virsh list --all 2>/dev/null | grep -c running || echo 0) VMs running\" || echo '✗ inactive'"
        },
        "break",
        {
            "type": "custom",
            "format": "\u001b[90m  Type 'cloudws --help' for commands\u001b[0m"
        },
        "break"
    ]
}
EOFF

# ═══ PROFILE.D — fastfetch + MOTD on terminal/TTY open ═══
echo "[39-desktop-polish] Updating profile.d for terminal/TTY..."
cat > /etc/profile.d/cloudws-motd.sh <<'EOPROFILE'
# CloudWS v2.0 — Terminal/TTY dashboard
# Shows fastfetch with services on interactive login
if [[ $- == *i* ]] && [ -z "${CLOUDWS_NO_MOTD:-}" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch 2>/dev/null || true
    else
        /usr/libexec/cloudws-motd 2>/dev/null || true
    fi
fi
EOPROFILE

echo "[39-desktop-polish] Desktop polish complete."
