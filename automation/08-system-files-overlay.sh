#!/bin/bash
# ============================================================================
# automation/08-system-files-overlay.sh - MiOS v0.1.3
# ----------------------------------------------------------------------------
# Overlay /ctx/ onto the rootfs during the Containerfile build,
# correctly handling the /usr/local -> /var/usrlocal symlink.
#
# v0.1.3 Architecture: Rootfs-Native
#   - Sources now directly from /ctx/usr, /ctx/etc, /ctx/var, /ctx/home
# ============================================================================
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

CTX="${CTX:-/ctx}"

# Warning reporting helper
report_warn() {
    local msg="$1"
    log "  WARN: $msg"
    if [[ -n "${MIOS_BUILD_STATE:-}" ]]; then
        touch "${MIOS_BUILD_STATE}/$(basename "$0").warn"
    fi
}

log "08-overlay: starting Rootfs-Native overlay"

# --- Stage 1: /usr (everything except /usr/local) --------------------------
if [[ -d "${CTX}/usr" ]]; then
    log "  stage 1: overlay usr content (excluding /usr/local)"
    tar -C "${CTX}/usr" -cf - --exclude='./local' . | tar -C /usr --no-overwrite-dir -xf -
else
    report_warn "/ctx/usr not found"
fi

# --- Stage 2: /usr/local via /var/usrlocal ---------------------------------
if [[ -d "${CTX}/usr/local" ]]; then
    log "  stage 2: overlay /usr/local content"
    if [[ -L /usr/local ]]; then
        log "    /usr/local is a symlink -> $(readlink /usr/local); writing through"
        install -d -m 0755 /var/usrlocal
        tar -C "${CTX}/usr/local" -cf - . | tar -C /var/usrlocal --no-overwrite-dir -xf -
    else
        log "    /usr/local is a real directory; writing directly"
        tar -C "${CTX}/usr/local" -cf - . | tar -C /usr/local --no-overwrite-dir -xf -
    fi
fi

# --- Stage 3: /etc (System Config Templates) -------------------------------
if [[ -d "${CTX}/etc" ]]; then
    log "  stage 3: overlay etc content"
    tar -C "${CTX}/etc" -cf - . | tar -C /etc --no-overwrite-dir -xf -
else
    report_warn "/ctx/etc not found"
fi

# --- Stage 4: /var (Mutable System State Templates) ------------------------
if [[ -d "${CTX}/var" ]]; then
    log "  stage 4: overlay var content"
    tar -C "${CTX}/var" -cf - . | tar -C /var --no-overwrite-dir -xf -
fi

# --- Stage 5: /home (User Space Templates) ---------------------------------
if [[ -d "${CTX}/home" ]]; then
    log "  stage 5: overlay home content"
    mkdir -p /var/home
    tar -C "${CTX}/home" -cf - . | tar -C /var/home --no-overwrite-dir -xf -
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

# === Pathing Compatibility ===
log "08-overlay: applying pathing compatibility symlinks"

# 1. WSL2 looks for /etc/wsl.conf, but we store it in /usr/lib/wsl.conf for immutability
if [[ -f /usr/lib/wsl.conf ]]; then
    ln -sf /usr/lib/wsl.conf /etc/wsl.conf
    log "  WSL: symlinked /etc/wsl.conf -> /usr/lib/wsl.conf"
fi

# 2. Standardize /home to /var/home (FCOS/bootc style)
if [ ! -L /home ] && [ -d /home ] && [ ! "$(ls -A /home)" ]; then
    rm -rf /home
    ln -sf /var/home /home
    log "  Path: symlinked /home -> /var/home"
elif [ ! -e /home ]; then
    ln -sf /var/home /home
    log "  Path: created /home -> /var/home symlink"
fi

# 3. Standardize /etc/locale.conf -> /usr/lib/locale.conf (USR-OVER-ETC)
if [[ -f /usr/lib/locale.conf ]]; then
    ln -sf /usr/lib/locale.conf /etc/locale.conf
    log "  Locale: symlinked /etc/locale.conf -> /usr/lib/locale.conf"
fi

# 4. Management binary symlinks
log "  Path: creating management symlinks"
ln -sf /usr/libexec/mios/motd /usr/bin/mios-motd
ln -sf /usr/libexec/mios/dash /usr/bin/mios-dash
ln -sf /usr/libexec/mios/mios-toggle-headless /usr/bin/mios-toggle-headless
ln -sf /usr/libexec/mios/mios-test /usr/bin/mios-test
ln -sf /usr/libexec/mios/mios-podman-gc /usr/bin/mios-podman-gc
ln -sf /usr/libexec/mios/assess /usr/bin/mios-assess
ln -sf /usr/libexec/mios/preflight /usr/bin/mios-preflight
ln -sf /usr/libexec/mios/cpu-isolate /usr/bin/mios-cpu-isolate
ln -sf /usr/libexec/mios/sb-audit /usr/bin/mios-sb-audit
ln -sf /usr/libexec/mios/sb-keygen /usr/bin/mios-sb-keygen
ln -sf /usr/libexec/mios/tpm-enroll /usr/bin/mios-tpm-enroll
ln -sf /usr/libexec/mios/role-apply /usr/bin/mios-role
ln -sf /usr/bin/systemd-sysext /usr/bin/mios-sysext

# 5. Unified logging/artifacting (USR-OVER-ETC pattern)
log "  Path: ensuring unified state directories exist in /usr"
mkdir -p /usr/lib/mios/logs /usr/lib/mios/artifacts /usr/lib/mios/backups /usr/lib/mios/snapshots
# NOTE: Symlinks from /var -> /usr are now managed via usr/lib/tmpfiles.d/mios-infra.conf
# to ensure compatibility with bootc container lint.

log "08-overlay: relabeling overlaid files"
restorecon -RFv /usr/ 2>/dev/null || true
restorecon -RFv /etc/ 2>/dev/null || true

log "08-overlay: complete"
