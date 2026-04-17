#!/usr/bin/bash
# 52-bake-kvmfr.sh - compile Looking Glass kvmfr kmod against the ucore-hci
# kernel shipped in the base image, sign it with the ublue MOK, and bake the
# .ko into /usr/lib/modules/$KVER/extra/kvmfr/.
#
# This runs INSIDE the Containerfile build. No runtime compile. BAKED IN -
# WHEN POSSIBLE.
#
# v2.3.4 fix (supersedes v2.2.8):
#   The previous `if ! dnf5 -y install ... 2>/dev/null; then ... fi` plus
#
#       AVAIL_REPO="$(dnf5 --showduplicates repoquery ... | tail -5 | tr ...)"
#
#   was tripping the whole script with exit 2 BEFORE reaching the graceful-
#   skip block. Root cause: `VAR="$(failing-pipeline)"` under set -euo pipefail
#   causes set -e to fire on the assignment when the pipeline's first command
#   exits non-zero (pipefail promotes the failure). Verified with a reproducer.
#
#   Fix: wrap every dnf5/rpm/dnf5-repoquery call in an explicit
#   `set +e` / `RC=$?` / `set -e` guard. Drop the unreliable repoquery
#   diagnostic entirely - the log line is still informative without it.
#   Looking Glass still runs IVSHMEM-only without kvmfr.
set -euo pipefail

log() { printf '[52-kvmfr] %s\n' "$*"; }

# --- Detect the kernel version shipped in the base image -------------------
KVER="$(find /usr/lib/modules/ -mindepth 1 -maxdepth 1 -printf "%f\n" 2>/dev/null | sort -V | tail -1)"
if [[ -z "$KVER" ]]; then
    log "WARN: no kernel modules directory; cannot determine kernel version"
    log "      skipping kvmfr bake - Looking Glass will run in IVSHMEM-only mode"
    exit 0
fi
log "building against kernel: $KVER"

# --- Try to get kernel-devel-$KVER exactly matched -------------------------
if [[ ! -d "/usr/src/kernels/$KVER" ]]; then
    log "installing kernel-devel-$KVER"
    set +e
    dnf5 -y install "kernel-devel-$KVER" >/dev/null 2>&1
    RC=$?
    set -e
    if [[ $RC -ne 0 ]]; then
        set +e
        AVAIL="$(rpm -qa 'kernel-devel*' 2>/dev/null | tr '\n' ' ')"
        set -e
        log "SKIP: no exact kernel-devel for $KVER (dnf5 rc=$RC; installed: ${AVAIL:-none})"
        log "      The ucore-hci base kernel $KVER is typically newer/older than"
        log "      F44's repo-published kernel-devel. Project principle is 'never"
        log "      upgrade base kernel in-container', so kvmfr is skipped here."
        log "      Looking Glass still works in IVSHMEM-only mode. To enable kvmfr"
        log "      on the booted image once the kernel matches, run:"
        log "         sudo dnf5 install kernel-devel-\$(uname -r) akmod-kvmfr"
        log "         sudo akmods --force --kernels \$(uname -r)"
        exit 0
    fi
fi

# --- Install akmod-kvmfr (from hikariknight/looking-glass-kvmfr COPR) ------
log "installing akmod-kvmfr"
set +e
dnf5 -y install akmod-kvmfr >/dev/null 2>&1
RC=$?
set -e
if [[ $RC -ne 0 ]]; then
    log "SKIP: akmod-kvmfr install failed (rc=$RC; COPR unreachable or package missing)"
    log "      verify COPR enabled: dnf5 copr list | grep looking-glass-kvmfr"
    exit 0
fi

# --- Force-build kvmfr kmod for this kernel --------------------------------
log "running akmods --force --kernels $KVER"
set +e
akmods --force --kernels "$KVER" 2>&1 | sed 's/^/[akmods] /'
RC=${PIPESTATUS[0]}
set -e
if [[ $RC -ne 0 ]]; then
    log "SKIP: akmods build failed (rc=$RC)"
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