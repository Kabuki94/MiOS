#!/bin/bash
# CloudWS — 10-gnome: MINIMAL GNOME 50 shell + essential Flatpaks ONLY
# NO bloat visible. NO user apps as RPMs. System infrastructure only.
#
# CRITICAL: NEVER use `dnf remove` on GNOME bloat — malcontent, gnome-tour, etc.
# are hard dependencies of gnome-shell/gdm. Removing them cascades and destroys
# the entire desktop. Instead, HIDE bloat with .desktop override files.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ═══ 1. MINIMAL GNOME SHELL (RPMs — system infrastructure only) ═══
install_packages "gnome"

systemctl enable gdm.service NetworkManager.service
systemctl set-default graphical.target

# ═══ 2. HIDE BLOAT with .desktop overrides (NoDisplay=true) ═══
# NEVER dnf remove these — they're hard deps of gnome-shell/gdm.
# Override files in /usr/local/share/applications take priority.
echo "[10-gnome] Hiding bloat apps via .desktop overrides..."
mkdir -p /usr/local/share/applications
BLOAT_APPS=(
    # GNOME bloat (deps of gnome-shell — can't remove, only hide)
    org.gnome.Tour
    org.gnome.Calendar
    org.gnome.Clocks
    org.gnome.Weather
    org.gnome.Contacts
    org.gnome.Maps
    org.gnome.Characters
    org.gnome.font-viewer
    org.gnome.Connections
    org.gnome.TextEditor
    org.gnome.Calculator
    org.gnome.Photos
    org.gnome.Music
    org.gnome.Cheese
    org.gnome.baobab
    org.gnome.Snapshot
    org.gnome.Logs
    org.gnome.DiskUtility
    org.gnome.FileRoller
    org.gnome.Evince
    org.gnome.Loupe
    org.gnome.Totem
    org.gnome.SystemMonitor
    org.gnome.tweaks
    org.gnome.Console
    org.gnome.Camera
    simple-scan
    yelp
    malcontent-control
    # Wine internal tools (users use Bottles/Lutris, not raw Wine)
    wine
    wine-notepad
    wine-winecfg
    wine-regedit
    wine-winehelp
    wine-winefile
    wine-uninstaller
    wine-oleview
    wine-wineboot
    # Misc bloat
    gamt
)
for app in "${BLOAT_APPS[@]}"; do
    cat > "/usr/local/share/applications/${app}.desktop" <<EOHIDE
[Desktop Entry]
Type=Application
Name=${app}
NoDisplay=true
Hidden=true
EOHIDE
done
echo "[10-gnome] ${#BLOAT_APPS[@]} bloat apps hidden"

# ═══ 3. GEIST FONT (Vercel) ═══
echo "[10-gnome] Installing Geist font family..."
mkdir -p /usr/share/fonts/geist
git clone --depth=1 https://github.com/vercel/geist-font.git /tmp/geist-font 2>/dev/null || true
if [ -d /tmp/geist-font ]; then
    find /tmp/geist-font -name "*.otf" -o -name "*.ttf" | xargs -I{} cp {} /usr/share/fonts/geist/ 2>/dev/null || true
    rm -rf /tmp/geist-font
    fc-cache -f 2>/dev/null || true
fi

# ═══ 4. BIBATA CURSOR ═══
echo "[10-gnome] Installing Bibata-Modern-Classic cursor..."
BIBATA_VER="2.0.7"
mkdir -p /usr/share/icons
curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz" \
    -o /tmp/bibata.tar.xz 2>/dev/null || true
if [ -f /tmp/bibata.tar.xz ]; then
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/ 2>/dev/null || true
    rm -f /tmp/bibata.tar.xz
fi

# ═══ 5. FLATPAK REMOTES ═══
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true

# ═══ 6. ESSENTIAL FLATPAKS ONLY — zero bloat, all uninstallable by user ═══
echo "[10-gnome] Installing essential Flatpaks..."
flatpak install -y --noninteractive flathub org.gnome.Epiphany 2>/dev/null || true
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager 2>/dev/null || true
flatpak install -y --noninteractive flathub io.podman_desktop.PodmanDesktop 2>/dev/null || true
flatpak install -y --noninteractive flathub com.vscodium.codium 2>/dev/null || true
flatpak install -y --noninteractive flathub-beta com.usebottles.bottles 2>/dev/null || true
flatpak install -y --noninteractive flathub org.gnome.Logs 2>/dev/null || true

# ═══ 7. COCKPIT AS EPIPHANY WEB APP (pinned to dock) ═══
mkdir -p /usr/share/applications
cat > /usr/share/applications/cloudws-cockpit.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=CloudWS Cockpit
Comment=Web-based server management dashboard
Exec=flatpak run org.gnome.Epiphany --application-mode https://localhost:9090
Icon=utilities-system-monitor
Categories=System;
StartupNotify=true
EOF

# ═══ 8. DCONF UPDATE ═══
dconf update 2>/dev/null || true

echo "[10-gnome] GNOME 50 minimal + Geist + Bibata + Flatpaks + Cockpit web app installed."
echo "[10-gnome] ${#BLOAT_APPS[@]} bloat apps hidden via NoDisplay=true overrides."
