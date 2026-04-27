#!/bin/bash
# ============================================================================
# automation/08-system-files-overlay.sh - MiOS v2.1.0
# ----------------------------------------------------------------------------
# Overlay /ctx/overlay/ onto the rootfs during the Containerfile build,
# correctly handling the /usr/local -> /var/usrlocal symlink that ships on
# ucore / Fedora CoreOS / bootc images.
#
# v2.1.0: USR-OVER-ETC policy applied. overlay/etc/ migrated to /usr/.
#
# This script is idempotent and safe to call repeatedly.
# ============================================================================
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

CTX="${CTX:-/ctx}"
SRC="${CTX}/system_files"

if [[ ! -d "${SRC}" ]]; then
    log "08-overlay: no ${SRC} directory; nothing to overlay"
    exit 0
fi

log "08-overlay: starting overlay (USR-OVER-ETC aligned)"

# --- Stage 1: everything except /usr/local ---------------------------------
# All system_files are now under usr/ in the source.
log "  stage 1: overlay usr content (excluding /usr/local)"
if [[ -d "${SRC}/usr" ]]; then
    tar -C "${SRC}/usr" -cf - --exclude='./local' . | tar -C /usr --no-overwrite-dir -xf -
fi

# --- Stage 2: /usr/local via /var/usrlocal ---------------------------------
if [[ -d "${SRC}/usr/local" ]]; then
    log "  stage 2: overlay /usr/local content"
    if [[ -L /usr/local ]]; then
        log "    /usr/local is a symlink -> $(readlink /usr/local); writing through"
        install -d -m 0755 /var/usrlocal
        tar -C "${SRC}/usr/local" -cf - . | tar -C /var/usrlocal --no-overwrite-dir -xf -
    else
        log "    /usr/local is a real directory; writing directly"
        tar -C "${SRC}/usr/local" -cf - . | tar -C /usr/local --no-overwrite-dir -xf -
    fi
fi

# Normalize permissions on systemd unit and config files.
log "08-overlay: normalizing systemd file permissions"
find /usr/lib/systemd -type f \( -name "*.service" -o -name "*.socket" -o -name "*.timer" -o -name "*.mount" -o -name "*.conf" -o -name "*.target" -o -name "*.path" -o -name "*.slice" -o -name "*.preset" -o -name "*.automount" -o -name "*.swap" \) -exec chmod 644 {} \; 2>/dev/null || true
find /usr/lib/systemd -type d -exec chmod 755 {} \; 2>/dev/null || true

# Logically Bound Images
QDIR="/usr/share/containers/systemd"
BDIR="/usr/lib/bootc/bound-images.d"
if [[ -d "${QDIR}" ]]; then
    install -d -m 0755 "${BDIR}"
    shopt -s nullglob
    for q in "${QDIR}"/*.container; do
        name="$(basename "$q")"
        ln -sf "${QDIR}/${name}" "${BDIR}/${name}"
        log "  LBI: bound ${name}"
    done
    shopt -u nullglob
fi

# ═══ WSL2 & Pathing Compatibility ═══
log "08-overlay: applying WSL2 and pathing compatibility symlinks"

# 1. WSL2 looks for /etc/wsl.conf, but we store it in /usr/lib/wsl.conf for immutability (USR-OVER-ETC)
if [[ -f /usr/lib/wsl.conf ]]; then
    ln -sf /usr/lib/wsl.conf /etc/wsl.conf
    log "  WSL: symlinked /etc/wsl.conf -> /usr/lib/wsl.conf"
fi

# 2. Standardize /home to /var/home (FCOS/bootc style)
# Ensure the target directory exists so the symlink isn't dangling during linting.
mkdir -p /var/home
if [ ! -L /home ] && [ -d /home ] && [ ! "$(ls -A /home)" ]; then
    rm -rf /home
    ln -sf /var/home /home
    log "  Path: symlinked /home -> /var/home"
elif [ ! -e /home ]; then
    ln -sf /var/home /home
    log "  Path: created /home -> /var/home symlink"
fi

log "08-overlay: relabeling overlaid files"
restorecon -RFv /usr/ 2>/dev/null || true

log "08-overlay: complete"
