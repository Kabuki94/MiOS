#!/bin/bash
# CloudWS — 10-gnome: MINIMAL GNOME 50 shell + essential Flatpaks ONLY
# NO bloat. NO user apps as RPMs. System infrastructure only.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ═══ 1. MINIMAL GNOME SHELL (RPMs — system infrastructure only) ═══
install_packages "gnome"

# ═══ 2. STRIP BLOAT pulled in as GNOME dependencies ═══
echo "[10-gnome] Removing bloat pulled in as dependencies..."
dnf remove -y --noautoremove \
    gnome-tour gnome-user-docs gnome-initial-setup \
    malcontent malcontent-control \
    gnome-maps gnome-weather gnome-contacts gnome-clocks \
    gnome-calendar gnome-characters gnome-font-viewer \
    gnome-connections gnome-text-editor gnome-calculator \
    gnome-photos gnome-music simple-scan cheese baobab yelp \
    totem evince loupe file-roller gnome-system-monitor \
    gnome-tweaks snapshot gnome-console gnome-logs \
    gnome-disk-utility gnome-camera \
    2>/dev/null || true

systemctl enable gdm.service NetworkManager.service
systemctl set-default graphical.target

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

# ═══ 6. ESSENTIAL FLATPAKS ONLY — zero bloat, all uninstallable ═══
echo "[10-gnome] Installing essential Flatpaks (no bloat)..."
# Browser — used for Cockpit web app too
flatpak install -y --noninteractive flathub org.gnome.Epiphany 2>/dev/null || true
# Extension Manager — manage GNOME extensions
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager 2>/dev/null || true
# Podman Desktop — container management GUI
flatpak install -y --noninteractive flathub io.podman_desktop.PodmanDesktop 2>/dev/null || true
# VSCodium — open-source VS Code
flatpak install -y --noninteractive flathub com.vscodium.codium 2>/dev/null || true
# Bottles — Windows app runner (Wine prefix manager)
flatpak install -y --noninteractive flathub-beta com.usebottles.bottles 2>/dev/null || true
# Logs — systemd journal viewer
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

# ═══ 8. DCONF: dark theme, Geist font, Bibata cursor, dock, folders ═══
dconf update 2>/dev/null || true

echo "[10-gnome] GNOME 50 minimal shell + Geist + Bibata + essential Flatpaks installed."
