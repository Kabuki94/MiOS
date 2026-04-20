#!/bin/bash
set -euo pipefail

# Suppress DBus/dconf warnings in headless build/early-boot environments
export GIO_USE_VFS=local
export GSETTINGS_BACKEND=memory

VER=1
VER_FILE="/etc/cloudws/.flatpak-version"
SCRIPT_HASH=$(sha256sum "$0" | cut -d' ' -f1)
VER_RUN="${VER}-${SCRIPT_HASH}"
FLATPAK_LIST="/usr/share/cloudws/flatpak-list"
LOG="/var/log/cloudws-flatpak-install.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }
if [ -f "$VER_FILE" ] && [ "$(cat "$VER_FILE")" = "$VER_RUN" ]; then
    log "Already at version ${VER}"; exit 0
fi
mkdir -p /etc/cloudws
log "CloudWS Flatpak installer v${VER}"
flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora 2>&1 | tee -a "$LOG" || true
flatpak remote-modify --system --disable fedora-testing 2>&1 | tee -a "$LOG" || true
if [ -f "$FLATPAK_LIST" ]; then
    log "Installing from ${FLATPAK_LIST}..."
    while IFS= read -r app || [ -n "$app" ]; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        log "  -> ${app}"
        flatpak install -y --noninteractive --system flathub "$app" 2>&1 | tee -a "$LOG" || log "  WARN: ${app} failed"
    done < "$FLATPAK_LIST"
fi
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>&1 | tee -a "$LOG" || true
flatpak override --system --env=GTK_THEME=adw-gtk3-dark 2>&1 | tee -a "$LOG" || true
echo "$VER_RUN" > "$VER_FILE"
log "Complete"
