#!/bin/bash
# CloudWS — 10-gnome: GNOME 50 desktop (individual packages, NO @gnome-desktop group)
# User-facing apps are Flatpaks. Only system packages here.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# Install only specified GNOME packages — NOT the full @gnome-desktop group
install_packages "gnome"

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

# Flathub remotes
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true

# Pre-install essential Flatpaks
flatpak install -y --noninteractive flathub \
    com.mattjakeman.ExtensionManager \
    io.podman_desktop.PodmanDesktop \
    com.visualstudio.code 2>/dev/null || true

# System-wide dark theme + Geist font + Bibata cursor via dconf
dconf update

echo "[10-gnome] GNOME 50 + Geist font + Bibata cursor + Flatpaks initialized."
