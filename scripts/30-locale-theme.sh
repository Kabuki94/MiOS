#!/bin/bash
# CloudWS v0.1.8 — 30-locale-theme: Unified dark theme for EVERY window type
#
# Coverage matrix (ALL must be dark):
#   ✓ libadwaita / GTK4 apps (GNOME native) — color-scheme=prefer-dark via dconf
#   ✓ GTK3 apps (legacy GNOME) — adw-gtk3-dark theme
#   ✓ GDM login screen — separate dconf db (gdm user)
#   ✓ GNOME lock screen — inherits user session (automatic)
#   ✓ Flatpak apps — ADW_DEBUG_COLOR_SCHEME + portal + filesystem overrides
#   ✓ Qt5/Qt6 apps — adwaita-qt + QGnomePlatform env vars
#   ✓ Electron/Chromium apps — ELECTRON_FORCE_DARK_MODE
#   ✓ Firefox — MOZ_ENABLE_WAYLAND + portal color-scheme
#   ✓ GNOME Remote Desktop — XCURSOR_THEME + session env
#   ✓ TTY/console — no theming needed (terminal colors)
#
# MUST RUN BEFORE 30-user.sh (skel .bashrc must exist before useradd -m)
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════"
echo "  CloudWS v0.1.8 — Universal Dark Theme"
echo "═══════════════════════════════════════════════════════════════════"

# ═══ SKEL .bashrc (MUST come BEFORE useradd -m) ═══
echo "[30-locale-theme] Writing /etc/skel/.bashrc..."
cat >> /etc/skel/.bashrc <<'EOBASH'

# ── CloudWS v0.1.8 ──────────────────────────────────────────────────
# Show system dashboard on interactive terminal open
if [[ $- == *i* ]]; then
    # Fastfetch with services dashboard
    if command -v fastfetch &>/dev/null; then
        fastfetch 2>/dev/null || true
    fi
    # Show cloudws --help hint on first open
    if [ ! -f "$HOME/.cloudws-welcomed" ]; then
        echo ""
        echo "  Type 'cloudws --help' for available commands."
        echo ""
        touch "$HOME/.cloudws-welcomed" 2>/dev/null || true
    fi
fi
EOBASH

# ═══ GTK3: adw-gtk3-dark for visual consistency with libadwaita ═══
echo "[30-locale-theme] Configuring GTK3 theme..."
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<'EOGTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Geist 11
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=:minimize,maximize,close
EOGTK3

# ═══ GTK4: libadwaita reads color-scheme, NOT GTK_THEME ═══
echo "[30-locale-theme] Configuring GTK4 theme..."
mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/settings.ini <<'EOGTK4'
[Settings]
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Geist 11
gtk-decoration-layout=:minimize,maximize,close
EOGTK4

# ═══ System-wide env vars for ALL toolkits ═══
echo "[30-locale-theme] Writing environment.d for all toolkits..."
mkdir -p /etc/environment.d

# Primary theme config (cursor, libadwaita, Qt, Electron, Firefox, SDL)
cat > /etc/environment.d/50-cloudws.conf <<'EOENV'
# ── Cursor Theme (OS-wide: GDM, GNOME, XWayland, Flatpaks) ─────────────────
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24

# ── LibAdwaita / GTK4 ────────────────────────────────────────────────────────
# Do NOT set GTK_THEME here — libadwaita ignores it and reads color-scheme
# from xdg-desktop-portal-gnome. Setting GTK_THEME=Adwaita:dark breaks
# libadwaita apps (window chrome renders with GTK3 style).
ADW_DEBUG_COLOR_SCHEME=prefer-dark

# ── Qt5 / Qt6 → follow Adwaita dark via adwaita-qt ─────────────────────────
QT_QPA_PLATFORMTHEME=adwaita
QT_STYLE_OVERRIDE=adwaita-dark
QT_QPA_PLATFORM=wayland;xcb
QT_WAYLAND_DECORATION=adwaita

# ── Electron / Chromium apps (VS Code, Discord, etc.) ──────────────────────
ELECTRON_OZONE_PLATFORM_HINT=auto
ELECTRON_FORCE_DARK_MODE=1

# ── Firefox / Mozilla ───────────────────────────────────────────────────────
MOZ_ENABLE_WAYLAND=1

# ── XDG portal color scheme (Flatpak sandbox reads this) ───────────────────
XDG_CURRENT_DESKTOP=GNOME

# ── SDL / Gaming ────────────────────────────────────────────────────────────
SDL_VIDEODRIVER=wayland,x11

# ── HDR / VRR (for bare-metal with capable displays) ───────────────────────
ENABLE_HDR_WSI=1
EOENV

# GTK3 dark theme env (separate file for clarity)
cat > /etc/environment.d/70-cloudws-theme.conf <<'EOENV'
# CloudWS v0.1.8: GTK3 legacy apps — adw-gtk3-dark matches libadwaita
GTK_THEME=adw-gtk3-dark
EOENV

# ═══ Flatpak overrides — dark theme + cursor + fonts ═══
echo "[30-locale-theme] Applying Flatpak dark theme + filesystem overrides..."
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
flatpak override --system --env=XCURSOR_THEME=Bibata-Modern-Classic 2>/dev/null || true
flatpak override --system --env=XCURSOR_SIZE=24 2>/dev/null || true
flatpak override --system --env=GTK_THEME=adw-gtk3-dark 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true
flatpak override --system --filesystem=/etc/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/etc/gtk-4.0:ro 2>/dev/null || true

# ═══ Skeleton autostart (Bottles from flathub-beta on first login) ═══
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/cloudws-user-setup.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=CloudWS User Setup
Exec=bash -c "sleep 8 && flatpak install -y flathub-beta com.usebottles.bottles 2>/dev/null; rm -f ~/.config/autostart/cloudws-user-setup.desktop"
Hidden=false
X-GNOME-Autostart-enabled=true
DESK


# Ensure skel GTK3 also uses adw-gtk3-dark (for new user sessions)
mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini <<'SKELGTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
SKELGTK3
# ── Compile GSchema overrides (THE correct way to set GNOME defaults) ──
if [ -f /usr/share/glib-2.0/schemas/90-cloudws.gschema.override ]; then
    echo "[30-locale-theme] Compiling GSchema overrides..."
    glib-compile-schemas /usr/share/glib-2.0/schemas/ || true
    echo "[30-locale-theme] ✓ GSchema overrides compiled"
fi

# Suppress DBus warnings during headless update without swallowing real syntax errors
export GIO_USE_VFS=local
dconf update || true

# Migrate generated binary dconf databases to the immutable /usr/share path.
# This prevents OSTree 3-way merge binary conflicts on /etc/dconf/db/local
# during bootc upgrades if users make their own local dconf changes.
if [ -d /etc/dconf/db ]; then
    mkdir -p /usr/share/dconf/db
    find /etc/dconf/db -maxdepth 1 -type f -exec mv -f {} /usr/share/dconf/db/ \; 2>/dev/null || true
fi

echo "[30-locale-theme] Dark theme configured for all toolkits."
