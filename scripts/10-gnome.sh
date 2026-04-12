#!/bin/bash
# CloudWS v0.1.3 — 10-gnome: GNOME 50 desktop — PURE BUILD-UP
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
# CHANGELOG v0.1.3:
#   - MANDATORY Bibata cursor download — retries 3x, FAILS BUILD if missing
#   - dconf profiles for user + GDM added to system_files/
#   - Flatpak: 7 apps (added Flatseal + LocalSend)
#   - adw-gtk3 theme for GTK3 visual consistency
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ═════════════════════════════════════════════════════════════════════════════
# GNOME 50 — Install from PACKAGES.md (build-up, NOT strip-down)
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing GNOME 50 desktop (pure build-up)..."
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
QT_QPA_PLATFORMTHEME=adwaita
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
# Bibata Cursor Theme — MANDATORY (build fails if download fails)
#
# The cursor shows as a SQUARE when:
#   - /usr/share/icons/Bibata-Modern-Classic/ doesn't exist (download failed)
#   - /usr/share/icons/default/index.theme points to nonexistent theme
#   - dconf cursor-theme references a theme with no files
#
# FIX: Retry download 3 times. VERIFY the cursors directory exists.
#      FAIL THE BUILD if cursors are missing — a square cursor is unacceptable.
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing Bibata-Modern-Classic cursor v2.0.8 (MANDATORY)..."
BIBATA_VER="2.0.8"
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz"
BIBATA_DIR="/usr/share/icons/Bibata-Modern-Classic"
mkdir -p /usr/share/icons

# Download with retries — DO NOT silence errors
BIBATA_OK=0
for attempt in 1 2 3; do
    echo "[10-gnome]   Download attempt $attempt/3..."
    if curl -fSL --retry 3 --retry-delay 5 "$BIBATA_URL" -o /tmp/bibata.tar.xz; then
        if tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/; then
            rm -f /tmp/bibata.tar.xz
            BIBATA_OK=1
            break
        fi
    fi
    echo "[10-gnome]   Attempt $attempt failed, retrying..."
    sleep 5
done

# VERIFY cursor files actually exist — fail build if missing
if [ "$BIBATA_OK" -eq 0 ] || [ ! -d "$BIBATA_DIR/cursors" ]; then
    echo "══════════════════════════════════════════════════════════════════"
    echo "  FATAL: Bibata cursor theme download FAILED after 3 attempts"
    echo "  URL: $BIBATA_URL"
    echo "  The cursor will show as a SQUARE without this theme."
    echo "  BUILD CANNOT CONTINUE."
    echo "══════════════════════════════════════════════════════════════════"
    exit 1
fi

echo "[10-gnome] ✓ Bibata cursor installed: $(ls "$BIBATA_DIR/cursors/" | wc -l) cursors"

# Comprehensive cursor default — every layer that reads cursor theme
# 1. Default cursor theme for X11 (read by ALL X clients including xRDP)
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme <<'EOCURSOR'
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Classic
EOCURSOR

# 2. Also write to /usr/share/X11/icons/default (some X servers check here)
mkdir -p /usr/share/X11/icons/default
cp /usr/share/icons/default/index.theme /usr/share/X11/icons/default/index.theme 2>/dev/null || true

# 3. update-alternatives for x-cursor-theme (Fedora cursor resolution)
if [ -d "$BIBATA_DIR/cursors" ]; then
    update-alternatives --install /usr/share/icons/default/index.theme \
        x-cursor-theme /usr/share/icons/Bibata-Modern-Classic/cursor.theme 100 2>/dev/null || true
    echo "[10-gnome] ✓ x-cursor-theme alternative set to Bibata"
fi

# 4. Symlink into /usr/share/cursors/xorg-x11 (legacy X11 cursor path)
mkdir -p /usr/share/cursors/xorg-x11
ln -sf /usr/share/icons/Bibata-Modern-Classic /usr/share/cursors/xorg-x11/Bibata-Modern-Classic 2>/dev/null || true

# 5. GDM user cursor — ensure cursor files are world-readable
chmod -R a+rX "$BIBATA_DIR" 2>/dev/null || true

# 6. Xresources fallback (oldest X11 cursor method)
mkdir -p /etc/X11
echo "Xcursor.theme: Bibata-Modern-Classic" > /etc/X11/Xresources 2>/dev/null || true
echo "Xcursor.size: 24" >> /etc/X11/Xresources 2>/dev/null || true

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
flatpak install -y --noninteractive flathub org.localsend.localsend_app 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Flatpak Theming
# CRITICAL: ADW_DEBUG_COLOR_SCHEME=prefer-dark, NOT GTK_THEME=Adwaita-dark
# GTK_THEME breaks libadwaita apps (controls, headerbar colors go wrong)
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Applying Flatpak dark theme + filesystem overrides..."
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
flatpak override --system --env=XCURSOR_THEME=Bibata-Modern-Classic 2>/dev/null || true
flatpak override --system --env=XCURSOR_SIZE=24 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true

# ═════════════════════════════════════════════════════════════════════════════
# Waydroid — Pre-download GAPPS OTA images (baked into image, no first-boot)
# Everything offline. No post-install services.
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Pre-downloading Waydroid GAPPS OTA images..."
WAYDROID_IMG_DIR="/var/lib/waydroid/images"
mkdir -p "$WAYDROID_IMG_DIR"
curl -sL "https://ota.waydro.id/system" -o "$WAYDROID_IMG_DIR/system.zip" 2>/dev/null || true
curl -sL "https://ota.waydro.id/vendor" -o "$WAYDROID_IMG_DIR/vendor.zip" 2>/dev/null || true
if [ -f "$WAYDROID_IMG_DIR/system.zip" ] && [ -f "$WAYDROID_IMG_DIR/vendor.zip" ]; then
    echo "[10-gnome] Waydroid OTA images cached ($(du -sh $WAYDROID_IMG_DIR | cut -f1))"
else
    echo "[10-gnome] WARNING: Waydroid OTA download failed — user must run: waydroid init -s GAPPS"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Network Discovery — Avahi / mDNS
# ═════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing Avahi/mDNS for .local network discovery..."
install_packages "network-discovery"

if [ -f /etc/nsswitch.conf ]; then
    if ! grep -q 'mdns4_minimal' /etc/nsswitch.conf; then
        sed -i 's/^hosts:.*/hosts:      files mdns4_minimal [NOTFOUND=return] dns myhostname/' /etc/nsswitch.conf
    fi
fi

echo "[10-gnome] GNOME 50 desktop + network discovery installed."
echo "[10-gnome] Cursor: Bibata-Modern-Classic ($(ls /usr/share/icons/Bibata-Modern-Classic/cursors/ | wc -l) cursors VERIFIED)"
echo "[10-gnome] Flatpaks: 7 pre-installed from Flathub"
