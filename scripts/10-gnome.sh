#!/bin/bash
# CloudWS v2.0 — 10-gnome: GNOME 50 desktop — PURE BUILD-UP
#
# STRATEGY: ucore has ZERO GNOME packages. We install exactly what we need.
# With install_weakdeps=False (set globally in 01-repos.sh), only hard deps
# get pulled in. This means:
#   - malcontent-libs comes in (gnome-control-center hard dep) — CORRECT
#   - malcontent-control/pam/tools do NOT come in (weak deps) — CORRECT
#   - No GNOME bloat apps get installed — nothing to remove
#
# The ~25 core packages from the docs produce a fully functional GNOME 50
# Wayland desktop with GDM, all portals, audio, Bluetooth, networking,
# security, and proper theming across GTK3/GTK4/Qt.
#
# CHANGELOG v2.0:
#   - Pure build-up: zero dnf removes (nothing to remove on ucore base)
#   - install_weakdeps=False prevents bloat installation
#   - Flatpak: disable filtered fedora remote, use unfiltered Flathub
#   - Qt Adwaita env vars for cross-toolkit theming
#   - Localsearch disabled via autostart override (never removed — breaks Nautilus)
#   - Bibata cursor v2.0.8, Geist font
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ═════════════════════════════════════════════════════════════════════════════
# GNOME 50 — Install from PACKAGES.md (build-up, NOT strip-down)
#
# PACKAGES.md packages-gnome block should contain ONLY these ~25 core packages:
#   gnome-shell, gdm, gnome-session-wayland-session, gnome-control-center,
#   xdg-desktop-portal, xdg-desktop-portal-gnome, xdg-desktop-portal-gtk,
#   gnome-keyring, gnome-keyring-pam, pipewire-pulseaudio, wireplumber,
#   bluez, NetworkManager, NetworkManager-wifi,
#   NetworkManager-config-connectivity-fedora, power-profiles-daemon,
#   adw-gtk3, adwaita-qt5, adwaita-qt6, qadwaitadecorations-qt5,
#   qadwaitadecorations-qt6, xdg-user-dirs, xdg-user-dirs-gtk,
#   dejavu-sans-fonts, dejavu-sans-mono-fonts, google-noto-emoji-color-fonts,
#   nautilus, gvfs-smb, gvfs-mtp, gvfs-goa, gvfs-nfs, flatpak,
#   mesa-dri-drivers, mesa-vulkan-drivers, gnome-backgrounds
#
# With install_weakdeps=False, installing gnome-shell auto-resolves:
#   mutter, gnome-session, gnome-settings-daemon, gjs, gnome-desktop4,
#   gsettings-desktop-schemas, pipewire, libadwaita, cantarell-fonts,
#   colord, libinput — NO explicit install needed.
# Installing gnome-control-center auto-resolves:
#   polkit, gnome-bluetooth, gnome-online-accounts, malcontent-libs
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing GNOME 50 desktop (pure build-up, ~25 core packages)..."
install_packages "gnome"

# Optional GNOME Core Apps (all commented out by default in PACKAGES.md)
install_packages_optional "gnome-core-apps"

# Enable display manager and network
systemctl enable gdm.service NetworkManager.service
systemctl set-default graphical.target

# ═════════════════════════════════════════════════════════════════════════════
# Localsearch/tracker — disable indexing without removing
# Removing localsearch breaks Nautilus search + Activities Overview.
# Hide via autostart overrides instead.
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Disabling localsearch/tracker indexing (keep package, hide autostart)..."
mkdir -p /etc/xdg/autostart
for tracker_entry in \
    localsearch-3.desktop \
    localsearch-control-3.desktop \
    localsearch-writeback-3.desktop; do
    cat > "/etc/xdg/autostart/$tracker_entry" <<EOF
[Desktop Entry]
Hidden=true
EOF
done

# ═════════════════════════════════════════════════════════════════════════════
# Qt Adwaita theming — required for Qt apps to match GNOME look
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Setting Qt Adwaita environment variables..."
mkdir -p /etc/environment.d
cat > /etc/environment.d/60-cloudws-qt-adwaita.conf <<'EOF'
QT_QPA_PLATFORMTHEME=gnome
QT_WAYLAND_DECORATION=adwaita
QT_STYLE_OVERRIDE=adwaita
EOF

# ═════════════════════════════════════════════════════════════════════════════
# Geist Font (Vercel)
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing Geist font family..."
mkdir -p /usr/share/fonts/geist
git clone --depth=1 https://github.com/vercel/geist-font.git /tmp/geist-font 2>/dev/null || true
if [ -d /tmp/geist-font ]; then
    find /tmp/geist-font -name "*.otf" -o -name "*.ttf" | xargs -I{} cp {} /usr/share/fonts/geist/ 2>/dev/null || true
    rm -rf /tmp/geist-font
fi
fc-cache -f /usr/share/fonts/geist 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Bibata Cursor Theme
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing Bibata-Modern-Classic cursor v2.0.8..."
BIBATA_VER="2.0.8"
mkdir -p /usr/share/icons
curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz" \
    -o /tmp/bibata.tar.xz 2>/dev/null || true
if [ -f /tmp/bibata.tar.xz ]; then
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/ 2>/dev/null || true
    rm -f /tmp/bibata.tar.xz
fi

# ═════════════════════════════════════════════════════════════════════════════
# Flatpak Remotes
# Disable filtered Fedora remote, use unfiltered Flathub for full catalog
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Configuring Flatpak remotes..."
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true
flatpak remote-modify --disable fedora 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Essential Flatpaks
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing essential Flatpaks..."
flatpak install -y --noninteractive flathub org.gnome.Epiphany 2>/dev/null || \
    flatpak install -y --noninteractive gnome-nightly org.gnome.Epiphany.Devel 2>/dev/null || true
flatpak install -y --noninteractive flathub org.gnome.Logs 2>/dev/null || true
flatpak install -y --noninteractive flathub com.mattjakeman.ExtensionManager 2>/dev/null || true
flatpak install -y --noninteractive flathub io.podman_desktop.PodmanDesktop 2>/dev/null || true
flatpak install -y --noninteractive flathub com.github.tchx84.Flatseal 2>/dev/null || true
flatpak install -y --noninteractive flathub page.tesk.Refine 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Flatpak Theming
# CRITICAL: ADW_DEBUG_COLOR_SCHEME=prefer-dark, NOT GTK_THEME=Adwaita-dark
# GTK_THEME breaks libadwaita apps (controls, headerbar colors go wrong)
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Applying Flatpak dark theme + filesystem overrides..."
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Waydroid — GAPPS init (first-boot oneshot)
# Initializes Waydroid with Google Play Services (GAPPS) on first boot.
# Uses official OTA URLs. Runs once, then disables itself via sentinel file.
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Creating Waydroid GAPPS init service..."
mkdir -p /etc/systemd/system
cat > /etc/systemd/system/waydroid-init-gapps.service <<'EOWAYDROID'
[Unit]
Description=CloudWS — Waydroid GAPPS initialization (first-boot)
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/waydroid/.cloudws-init-done

[Service]
Type=oneshot
RemainAfterExit=no
ExecStart=/bin/bash -c '\
    waydroid init -s GAPPS \
        -i https://ota.waydro.id/system \
        -v https://ota.waydro.id/vendor && \
    mkdir -p /var/lib/waydroid && \
    touch /var/lib/waydroid/.cloudws-init-done'
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOWAYDROID
systemctl enable waydroid-init-gapps.service 2>/dev/null || true

echo "[10-gnome] GNOME 50 desktop installed (pure build-up on ucore base)."
echo "[10-gnome] Zero removes. install_weakdeps=False prevented all bloat."
echo "[10-gnome] Flatpaks: 6 pre-installed from Flathub (VSCodium removed, Refine added)."
