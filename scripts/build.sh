#!/bin/bash
# CloudWS v1.3 — Master build runner
# Executes all numbered scripts in order, then cleans up.
# Called from Containerfile RUN layer via bind mount.
#
# CHANGELOG v1.3:
#   - Added post-build package validation (Bluefin pattern)
#   - Added third-party repo disable after build (Bazzite pattern)
#   - Added build summary with timing per script
#
# BUILD LOG: /tmp/cloudws-build.log (available during build for debugging)
# Each script gets timed. If a script hangs, the log shows exactly where.
#
# NOTE: We intentionally do NOT use set -e here because we want all scripts
# to run even if one fails, and we capture exit codes explicitly below.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PACKAGES_MD="${PACKAGES_MD:-/ctx/PACKAGES.md}"
BUILD_LOG="/tmp/cloudws-build.log"

# ── Logging setup ───────────────────────────────────────────────────────────
# Tee all output to both console AND log file
exec > >(tee -a "$BUILD_LOG") 2>&1

log_ts() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

VERSION_STR="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || cat /ctx/VERSION 2>/dev/null || echo '1.3.0')"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS v${VERSION_STR} — Building OS Image               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_ts "Build started"
log_ts "PACKAGES.MD : $PACKAGES_MD"
log_ts "SCRIPT_DIR  : $SCRIPT_DIR"
log_ts "BUILD_LOG   : $BUILD_LOG"
echo ""

# Validate PACKAGES.md is accessible
if [[ ! -f "$PACKAGES_MD" ]]; then
    log_ts "FATAL: $PACKAGES_MD not found. Build context missing."
    exit 1
fi

# ── DNF performance & reliability tweaks ────────────────────────────────────
export DNF_SETOPT="--setopt=install_weak_deps=True"
export SYSTEMD_OFFLINE=1
export container=podman

# ── Execute all numbered scripts in order ───────────────────────────────────
TOTAL_START=$SECONDS
SCRIPT_COUNT=0
SCRIPT_FAIL=0

for script in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
    SCRIPT_NAME="$(basename "$script")"
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log_ts "==> Running: $SCRIPT_NAME"
    echo "═══════════════════════════════════════════════════════════════"

    STEP_START=$SECONDS

    # Capture exit code explicitly — never rely on $? after an if/else branch
    set +e
    bash "$script"
    SCRIPT_EXIT=$?
    set -e

    STEP_ELAPSED=$(( SECONDS - STEP_START ))

    if [[ $SCRIPT_EXIT -eq 0 ]]; then
        log_ts "==> $SCRIPT_NAME completed (${STEP_ELAPSED}s)"
    else
        log_ts "==> $SCRIPT_NAME FAILED (exit $SCRIPT_EXIT, ${STEP_ELAPSED}s)"
        SCRIPT_FAIL=$((SCRIPT_FAIL + 1))
    fi
done

# ── Post-build: Validate critical packages ──────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_ts "==> Post-build validation"
echo "═══════════════════════════════════════════════════════════════"

CRITICAL_PACKAGES=(
    gnome-shell gdm podman bootc libvirt kernel firewalld cockpit
    NetworkManager pipewire tuned chronyd sshd
)
VALIDATION_FAIL=0
for pkg in "${CRITICAL_PACKAGES[@]}"; do
    if rpm -q "$pkg" > /dev/null 2>&1; then
        echo "  ✓ $pkg"
    else
        echo "  ✗ $pkg MISSING"
        VALIDATION_FAIL=$((VALIDATION_FAIL + 1))
    fi
done

# Validate NO footgun packages are present
FOOTGUN_PACKAGES=(
    PackageKit gnome-initial-setup gnome-tour
)
for pkg in "${FOOTGUN_PACKAGES[@]}"; do
    if rpm -q "$pkg" > /dev/null 2>&1; then
        echo "  ⚠ FOOTGUN: $pkg is installed (should be removed or hidden)"
    fi
done

if [[ $VALIDATION_FAIL -gt 0 ]]; then
    log_ts "WARNING: $VALIDATION_FAIL critical packages missing!"
fi

# ── Cleanup: Keep final image small ────────────────────────────────────────
echo ""
log_ts "Cleaning up..."
dnf clean all
rm -rf /var/cache/dnf /var/cache/libdnf5 /tmp/geist-font /tmp/*.tar* /tmp/*.rpm 2>/dev/null || true

# Preserve build log in image for debugging
cp "$BUILD_LOG" /var/log/cloudws-build.log 2>/dev/null || true
rm -f /tmp/cloudws-build.log

# ── Build summary ───────────────────────────────────────────────────────────
TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  BUILD COMPLETE                                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Scripts:   $SCRIPT_COUNT executed, $SCRIPT_FAIL failed"
echo "║  Packages:  $VALIDATION_FAIL critical missing"
echo "║  Duration:  ${TOTAL_ELAPSED}s ($((TOTAL_ELAPSED / 60))m $((TOTAL_ELAPSED % 60))s)"
echo "║  Version:   $VERSION_STR"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ $SCRIPT_FAIL -gt 0 ]]; then
    log_ts "WARNING: $SCRIPT_FAIL scripts failed — check log: /var/log/cloudws-build.log"
fi
