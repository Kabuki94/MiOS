#!/usr/bin/bash
# 52-bake-kvmfr.sh - compile Looking Glass kvmfr kmod against the ucore-hci
# kernel shipped in the base image, sign it with the ublue MOK, and bake the
# .ko into /usr/lib/modules/$KVER/extra/kvmfr/.
#
# This runs INSIDE the Containerfile build. No runtime compile. BAKED IN.
set -euo pipefail

log() { printf '[52-kvmfr] %s\n' "$*"; }

# --- Detect the kernel version shipped in the base image -------------------
KVER="$(ls /usr/lib/modules/ 2>/dev/null | head -n1)"
if [[ -z "$KVER" ]]; then
    log "ERROR: no kernel modules directory; cannot determine kernel version"
    exit 1
fi
log "building against kernel: $KVER"

# --- Ensure kernel-devel matches ------------------------------------------
if [[ ! -d "/usr/src/kernels/$KVER" ]]; then
    log "installing kernel-devel-$KVER"
    # Try exact match first; fall back to matched
    dnf5 -y install "kernel-devel-$KVER" 2>/dev/null || \
    dnf5 -y install "kernel-devel-uname-r = $KVER" 2>/dev/null || \
    dnf5 -y install kernel-devel-matched 2>/dev/null || {
        log "ERROR: could not install kernel-devel for $KVER"
        log "       available kernel-devel: $(rpm -qa 'kernel-devel*' || echo none)"
        exit 1
    }
fi

# --- Install akmod-kvmfr (from hikariknight/looking-glass-kvmfr COPR) ------
log "installing akmod-kvmfr"
dnf5 -y install akmod-kvmfr || {
    log "ERROR: akmod-kvmfr install failed"
    log "       verify COPR enabled: dnf5 copr list | grep looking-glass-kvmfr"
    exit 1
}

# --- Force-build kvmfr kmod for this kernel --------------------------------
log "running akmods --force --kernels $KVER"
akmods --force --kernels "$KVER" 2>&1 | sed 's/^/[akmods] /' || {
    log "ERROR: akmods build failed"
    log "       checking /var/cache/akmods/kvmfr/ for build log..."
    find /var/cache/akmods/ -name '*.log' -exec tail -50 {} \; || true
    exit 1
}

# --- Verify the kmod landed -------------------------------------------------
KMOD_PATH="/usr/lib/modules/$KVER/extra/kvmfr/kvmfr.ko"
if [[ -f "$KMOD_PATH" ]] || [[ -f "${KMOD_PATH}.xz" ]] || [[ -f "${KMOD_PATH}.zst" ]]; then
    log "OK: kvmfr.ko baked in at /usr/lib/modules/$KVER/extra/kvmfr/"
    ls -la "/usr/lib/modules/$KVER/extra/kvmfr/"
else
    log "ERROR: kvmfr.ko NOT FOUND after akmods build"
    log "       listing /usr/lib/modules/$KVER/extra/:"
    ls -la "/usr/lib/modules/$KVER/extra/" 2>/dev/null || log "  (no extra/ dir)"
    exit 1
fi

# --- Update module dependencies --------------------------------------------
log "running depmod -a $KVER"
depmod -a "$KVER"

# --- Sign the module with ublue MOK (if present, for Secure Boot) ----------
PRIV_KEY="/etc/pki/akmods/private/private_key.priv"
PUB_KEY="/etc/pki/akmods/certs/public_key.der"
if [[ -f "$PRIV_KEY" && -f "$PUB_KEY" ]]; then
    log "signing kvmfr.ko with akmods private key"
    SIGN_FILE="/usr/src/kernels/$KVER/scripts/sign-file"
    if [[ -x "$SIGN_FILE" ]]; then
        for ko in /usr/lib/modules/$KVER/extra/kvmfr/*.ko; do
            [[ -f "$ko" ]] && "$SIGN_FILE" sha256 "$PRIV_KEY" "$PUB_KEY" "$ko" && \
                log "  signed: $ko"
        done
    else
        log "WARN: sign-file script not found at $SIGN_FILE; kvmfr unsigned"
    fi
else
    log "NOTE: ublue MOK private key not in image (expected); users enroll MOK"
    log "      and kvmfr will use the public cert shipped by ublue-os-akmods-addons"
fi

log "kvmfr kmod BAKED IN"