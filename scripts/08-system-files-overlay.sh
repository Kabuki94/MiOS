#!/usr/bin/env bash
# ============================================================================
# scripts/08-system-files-overlay.sh - CloudWS-bootc v2.1.6
# ----------------------------------------------------------------------------
# Overlay /ctx/system_files/ onto the rootfs during the Containerfile build,
# correctly handling the /usr/local -> /var/usrlocal symlink that ships on
# ucore / Fedora CoreOS / bootc images. Replaces the failing inline RUN:
#
#   RUN ... cp -a /ctx/system_files/usr/local/. /usr/local/
#   cp: cannot create directory '/usr/local/': File exists
#
# The root cause is that /usr/local is a SYMLINK on these bases; `cp -a` with
# a trailing slash on the destination tries to create /usr/local as a
# directory, which collides with the existing symlink. The fix is to write
# through the symlink by tar-piping into /var/usrlocal directly.
#
# This script is idempotent and safe to call repeatedly.
#
# USAGE (from the Containerfile):
#     RUN /ctx/scripts/08-system-files-overlay.sh
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

log "08-overlay: starting 2-stage overlay (ucore /usr/local symlink aware)"

# --- Stage 1: everything except /usr/local ---------------------------------
# tar|tar preserves permissions, ownership, timestamps, xattrs (when
# supported on both sides) and avoids `cp`'s trailing-slash quirks.
log "  stage 1: overlay everything except /usr/local"
tar -C "${SRC}" -cf - --exclude='./usr/local' . | tar -C / --no-overwrite-dir -xf -

# --- Stage 2: /usr/local via /var/usrlocal ---------------------------------
# /usr/local is a symlink to /var/usrlocal on ucore/FCOS-lineage images.
# Writing through the symlink (tar -C /var/usrlocal) is the clean fix.
# On pure Fedora bootc bases where /usr/local is a real dir, writing to
# /var/usrlocal still works after we create it - we then ALSO overlay the
# real /usr/local so behaviour is identical on both lineages.
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
else
    log "  stage 2: skipped (no ${SRC}/usr/local)"
fi

# Normalize permissions on systemd unit and config files.
# Windows git clones leave files executable and world-writable; tar|tar above
# preserves those bits. systemd 259+ logs warnings and may reject such files.
# We restrict this strictly to unit file extensions to avoid breaking executables
# like /usr/lib/systemd/systemd itself.
log "08-overlay: normalizing systemd file permissions"
find /etc/systemd /usr/lib/systemd -type f \( -name "*.service" -o -name "*.socket" -o -name "*.timer" -o -name "*.mount" -o -name "*.conf" -o -name "*.target" -o -name "*.path" -o -name "*.slice" -o -name "*.preset" -o -name "*.automount" -o -name "*.swap" \) -exec chmod 644 {} \; 2>/dev/null || true
find /etc/systemd /usr/lib/systemd -type d -exec chmod 755 {} \; 2>/dev/null || true

# Logically Bound Images: symlink every Quadlet .container spec shipped via the
# overlay into /usr/lib/bootc/bound-images.d/ so `bootc` pre-fetches those
# images during OS upgrades. First-boot then runs without cold registry pulls.
# Dynamically-generated Quadlets (e.g. crowdsec-dashboard from 12-virt.sh) bind
# themselves at the script level.
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

log "08-overlay: relabeling overlaid files with correct SELinux contexts"
# Restore SELinux contexts for all files copied from system_files
restorecon -RFv /etc/ 2>/dev/null || true
restorecon -RFv /usr/ 2>/dev/null || true

log "08-overlay: complete"
