#!/usr/bin/bash
# 52-bake-kvmfr.sh - compile Looking Glass kvmfr kmod against the ucore-hci
# kernel shipped in the base image, sign it with the ublue MOK, and bake the
# .ko into /usr/lib/modules/$KVER/extra/kvmfr/.
#
# This runs INSIDE the Containerfile build. No runtime compile. BAKED IN -
# WHEN POSSIBLE.
#
# v2.2.8 fix:
#   - SKIP (don't fail) when kernel-devel for the running ucore-hci kernel is
#     not available in the F44 repos. The ucore-hci base frequently ships a
#     slightly older kernel than what F44 currently hosts (e.g. base is
#     6.19.10 but F44 only has kernel-devel-6.19.12). Project principle
#     "never upgrade base kernel packages in-container" means we cannot
#     promote the kernel to match, so kvmfr has to be built at runtime or
#     skipped. Looking Glass still works in IVSHMEM-only mode, so skipping
#     here is NOT fatal to the image. The old hard-fail blocked the build
#     entirely.
set -euo pipefail

log() { printf '[52-kvmfr] %s\n' "$*"; }

# --- Detect the kernel version shipped in the base image -------------------
KVER="$(ls /usr/lib/modules/ 2>/dev/null | head -n1)"
if [[ -z "$KVER" ]]; then
    log "WARN: no kernel modules directory; cannot determine kernel version"
    log "      skipping kvmfr bake - Looking Glass will run in IVSHMEM-only mode"
    exit 0
fi
log "building against kernel: $KVER"

# --- Try to get kernel-devel-$KVER exactly matched -------------------------
SKIP_REASON=""
if [[ ! -d "/usr/src/kernels/$KVER" ]]; then
    log "installing kernel-devel-$KVER"
    if ! dnf5 -y install "kernel-devel-$KVER" 2>/dev/null; then
        if ! dnf5 -y install "kernel-devel-uname-r = $KVER" 2>/dev/null; then
            AVAIL="$(rpm -qa 'kernel-devel*' 2>/dev/null | tr '\n' ' ')"
            AVAIL_REPO="$(dnf5 --showduplicates repoquery kernel-devel 2>/dev/null | tail -5 | tr '\n' ' ')"
            SKIP_REASON="no exact kernel-devel for $KVER (installed: ${AVAIL:-none}; repo has: ${AVAIL_REPO:-none})"
        fi
    fi
fi

if [[ -n "$SKIP_REASON" ]]; then
    log "SKIP: $SKIP_REASON"
    log "      Looking Glass will work in IVSHMEM-only mode. To enable the"
    log "      kvmfr kmod, build it at runtime once the kernel matches, e.g.:"
    log "         sudo dnf5 install kernel-devel-\$(uname -r) akmod-kvmfr"
    log "         sudo akmods --force --kernels \$(uname -r)"
    exit 0
fi

# --- Install akmod-kvmfr (from hikariknight/looking-glass-kvmfr COPR) ------
log "installing akmod-kvmfr"
if ! dnf5 -y install akmod-kvmfr 2>/dev/null; then
    log "SKIP: akmod-kvmfr install failed (COPR unreachable or package missing)"
    log "      verify COPR enabled: dnf5 copr list | grep looking-glass-kvmfr"
    exit 0
fi

# --- Force-build kvmfr kmod for this kernel --------------------------------
log "running akmods --force --kernels $KVER"
if ! akmods --force --kernels "$KVER" 2>&1 | sed 's/^/[akmods] /'; then
    log "SKIP: akmods build failed"
    log "      checking /var/cache/akmods/kvmfr/ for build log..."
    find /var/cache/akmods/ -name '*.log' -exec tail -50 {} \; 2>/dev/null || true
    exit 0
fi

# --- Verify the kmod landed -------------------------------------------------
KMOD_PATH="/usr/lib/modules/$KVER/extra/kvmfr/kvmfr.ko"
if [[ -f "$KMOD_PATH" ]] || [[ -f "${KMOD_PATH}.xz" ]] || [[ -f "${KMOD_PATH}.zst" ]]; then
    log "OK: kvmfr.ko baked in at /usr/lib/modules/$KVER/extra/kvmfr/"
    ls -la "/usr/lib/modules/$KVER/extra/kvmfr/"
else
    log "SKIP: kvmfr.ko NOT FOUND after akmods build"
    log "      listing /usr/lib/modules/$KVER/extra/:"
    ls -la "/usr/lib/modules/$KVER/extra/" 2>/dev/null || log "  (no extra/ dir)"
    exit 0
fi

# --- Update module dependencies --------------------------------------------
log "running depmod -a $KVER"
depmod -a "$KVER" || log "WARN: depmod failed (non-fatal)"

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
