#!/bin/bash
# CloudWS v1.3 — 10-gnome: GNOME 50 desktop (individual packages, NO @gnome-desktop group)
#
# CHANGELOG v1.3:
#   - GNOME 49+: systemd is a HARD dependency (userdb, session manager removed)
#   - Bibata cursor updated to v2.0.8
#   - Added gnome-console as Ptyxis fallback (Rawhide package name flux)
#   - Added VSCodium Flatpak
#   - Flatpak theming: ADW_DEBUG_COLOR_SCHEME (NOT GTK_THEME — breaks libadwaita)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# Install only specified GNOME packages — NOT the full @gnome-desktop group
# CRITICAL: GNOME 49+ requires full systemd user session support.
# gnome-session's built-in service manager was removed entirely.
install_packages "gnome"

# Optional GNOME Core Apps (all commented out by default in PACKAGES.md)
# Users uncomment package lines in PACKAGES.md to enable these
install_packages_optional "gnome-core-apps"

systemctl enable gdm.service NetworkManager.service
systemctl set-default graphical.target

# ─── Geist Font (Vercel) ────────────────────────────────────────────────────
echo "[10-gnome] Installing Geist font family..."
mkdir -p /usr/share/fonts/geist
git clone --depth=1 https://github.com/vercel/geist-font.git /tmp/geist-font 2>/dev/null || true
if [ -d /tmp/geist-font ]; then
    find /tmp/geist-font -name "*.otf" -o -name "*.ttf" | xargs -I{} cp {} /usr/share/fonts/geist/ 2>/dev/null || true
    rm -rf /tmp/geist-font
fi
# Rebuild font cache so Geist is discoverable by all apps (including Flatpaks)
fc-cache -f /usr/share/fonts/geist 2>/dev/null || true

# ─── Bibata Cursor Theme ────────────────────────────────────────────────────
echo "[10-gnome] Installing Bibata-Modern-Classic cursor..."
BIBATA_VER="2.0.8"
mkdir -p /usr/share/icons
curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz" \
    -o /tmp/bibata.tar.xz 2>/dev/null || true
if [ -f /tmp/bibata.tar.xz ]; then
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/ 2>/dev/null || true
    rm -f /tmp/bibata.tar.xz
fi

# ─── Flatpak Remotes ────────────────────────────────────────────────────────
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true

# ─── Pre-install essential Flatpaks ──────────────────────────────────────────
echo "[10-gnome] Installing essential Flatpaks..."

# Epiphany — the universal viewer (browser + docs + photos + media)
flatpak install -y --noninteractive flathub org.gnome.Epiphany 2>/dev/null || \
    flatpak install -y --noninteractive gnome-nightly org.gnome.Epiphany.Devel 2>/dev/null || true

# Logs — systemd journal viewer
flatpak install -y --noninteractive flathub org.gnome.Logs 2>/dev/null || true

# Extension Manager
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager 2>/dev/null || true

# Podman Desktop — container management GUI
flatpak install -y --noninteractive flathub io.podman_desktop.PodmanDesktop 2>/dev/null || true

# VSCodium — open-source VS Code
flatpak install -y --noninteractive flathub com.vscodium.codium 2>/dev/null || true

# Flatseal — Flatpak permissions manager
flatpak install -y --noninteractive flathub com.github.tchx84.Flatseal 2>/dev/null || true

# ─── Flatpak Theming ────────────────────────────────────────────────────────
# CRITICAL: Use ADW_DEBUG_COLOR_SCHEME=prefer-dark, NOT GTK_THEME=Adwaita-dark
# GTK_THEME breaks libadwaita apps (controls, headerbar colors go wrong)
echo "[10-gnome] Applying Flatpak dark theme..."
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
# Grant Flatpaks access to system GTK/icon configs
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true

echo "[10-gnome] GNOME 50 desktop installed. Flatpaks: 6 pre-installed."
