#!/bin/bash
# CloudWS v2.3.1 — 39-desktop-polish: Desktop entries, Cockpit webapp, MOTD
#
# CHANGELOG v2.3.1:
#   - FIX: cloudws-motd source path was /tmp/build/scripts/ (never exists).
#     Scripts run from /ctx/scripts/ in the buildroot. The bogus path + the
#     `|| true` swallowed the failure silently, so /usr/libexec/cloudws-motd
#     was never created. profile.d/cloudws-motd.sh falls back to it when
#     fastfetch is missing, so terminal MOTD printed nothing on every
#     v2.0-v2.2 image.
#   - FIX: SCRIPT_DIR-relative copy so this works whether build.sh invokes
#     us from /ctx/scripts/ or any other future path. If the source is
#     missing, FAIL LOUDLY (remove the silencing `|| true`) so it can't
#     regress unnoticed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
Terminal=false
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
Terminal=false
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
Terminal=false
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
Terminal=false
Icon=drive-harddisk
Categories=System;
Keywords=ceph;storage;
EODESKTOP

# Ensure strict, deterministic permissions for all generated desktop entries
chmod 0644 /usr/share/applications/cockpit.desktop \
           /usr/share/applications/cockpit-browser.desktop \
           /usr/share/applications/nvidia-settings.desktop \
           /usr/share/applications/ceph-dashboard.desktop

# ═══ MOTD DASHBOARD ═══
# Source lives alongside this script (scripts/cloudws-motd in the repo,
# /ctx/scripts/cloudws-motd at build time). SCRIPT_DIR resolves both.
# If the source file is missing, FAIL - better to break the build than
# ship an image with no MOTD.
echo "[39-desktop-polish] Installing CloudWS MOTD dashboard..."
MOTD_SRC="${SCRIPT_DIR}/cloudws-motd"
if [[ ! -f "$MOTD_SRC" ]]; then
    echo "[39-desktop-polish] FATAL: cloudws-motd not found at $MOTD_SRC"
    echo "[39-desktop-polish]        scripts/cloudws-motd must be present in repo"
    exit 1
fi
install -D -m 0755 "$MOTD_SRC" /usr/libexec/cloudws-motd
echo "[39-desktop-polish] ✓ /usr/libexec/cloudws-motd installed ($(wc -l <"$MOTD_SRC") lines)"

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
            "folders": "/sysroot"
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
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2 | head -1); [ -z \"$IP\" ] && IP=localhost; systemctl is-active --quiet cockpit.socket 2>/dev/null && echo \"✓ https://$IP:9090\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  🖥️  RDP",
            "keyColor": "green",
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2 | head -1); [ -z \"$IP\" ] && IP=localhost; (systemctl is-active --quiet gnome-remote-desktop 2>/dev/null || systemctl is-active --quiet xrdp 2>/dev/null) && echo \"✓ rdp://$IP:3389\" || echo '✗ inactive'"
        },
        {
            "type": "command",
            "key": "  🔒 SSH",
            "keyColor": "green",
            "text": "IP=$(ip -4 route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | cut -d' ' -f2 | head -1); [ -z \"$IP\" ] && IP=localhost; systemctl is-active --quiet sshd 2>/dev/null && echo \"✓ ssh://$IP:22\" || echo '✗ inactive'"
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
            "text": "if systemctl is-active --quiet firewalld 2>/dev/null; then echo '✓ active'; else echo '✗ inactive'; fi"
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
# fastfetch is the preferred frontend (ships its own per-service probes);
# cloudws-motd is the fallback. With v2.3.1 the 12-virt.sh containers section
# now completes, so "utils" gets installed, so fastfetch IS present - but we
# keep the fallback for minimal images that skip the utils section.
echo "[39-desktop-polish] Updating profile.d for terminal/TTY..."
cat > /etc/profile.d/cloudws-motd.sh <<'EOPROFILE'
# CloudWS v2.3.1 — Terminal/TTY dashboard
# Shows fastfetch services panel on interactive login.
# Suppress with:  export CLOUDWS_NO_MOTD=1
if [[ $- == *i* ]] && [ -z "${CLOUDWS_NO_MOTD:-}" ]; then
    if command -v fastfetch &>/dev/null; then
        fastfetch 2>/dev/null || true
    elif [[ -x /usr/libexec/cloudws-motd ]]; then
        /usr/libexec/cloudws-motd 2>/dev/null || true
    fi
fi
EOPROFILE
chmod 0644 /etc/profile.d/cloudws-motd.sh

echo "[39-desktop-polish] Desktop polish complete."
