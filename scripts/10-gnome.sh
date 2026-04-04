#!/bin/bash
# CloudWS — 10-gnome: GNOME 50 desktop (individual packages, NO @gnome-desktop group)
# Epiphany (browser) handles docs, photos, media. Only system packages here.
# Optional GNOME Core Apps can be enabled by uncommenting lines in PACKAGES.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# Install only specified GNOME packages — NOT the full @gnome-desktop group
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

# ─── Bibata Cursor Theme ────────────────────────────────────────────────────
echo "[10-gnome] Installing Bibata-Modern-Classic cursor..."
BIBATA_VER="2.0.7"
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

# Podman Desktop
flatpak install -y --noninteractive flathub io.podman_desktop.PodmanDesktop 2>/dev/null || true

# VSCodium
flatpak install -y --noninteractive flathub com.vscodium.codium 2>/dev/null || true

# ─── Flatpak theming ────────────────────────────────────────────────────────
# Grant Flatpaks read access to GTK/adwaita config dirs
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true

# Dark mode via ADW_DEBUG_COLOR_SCHEME — NOT GTK_THEME which breaks libadwaita
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true

echo "[10-gnome] GNOME 50 desktop configured."
