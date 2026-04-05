#!/bin/bash
# CloudWS — Master build runner
# Executes all numbered scripts in order, then cleans up.
# Called from Containerfile RUN layer via bind mount.
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

VERSION_STR="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || cat /ctx/VERSION 2>/dev/null || echo '1.0.0')"

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
        log_ts "==> Completed: $SCRIPT_NAME (${STEP_ELAPSED}s)"
    else
        log_ts "==> FAILED: $SCRIPT_NAME (${STEP_ELAPSED}s) — exit code $SCRIPT_EXIT"
        SCRIPT_FAIL=$((SCRIPT_FAIL + 1))
    fi
done

# ── Final cleanup — must be in same layer as installs ───────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_ts "==> Final cleanup"
echo "═══════════════════════════════════════════════════════════════"
dnf clean all
rm -rf /var/cache/dnf /var/cache/rpm /var/log/dnf* /var/log/hawkey* /root/.cache

TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
TOTAL_MIN=$(( TOTAL_ELAPSED / 60 ))
TOTAL_SEC=$(( TOTAL_ELAPSED % 60 ))

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS build complete                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
log_ts "Build finished: ${SCRIPT_COUNT} scripts, ${SCRIPT_FAIL} failures, ${TOTAL_MIN}m${TOTAL_SEC}s"

mkdir -p /var/log
cp "$BUILD_LOG" /var/log/cloudws-build.log 2>/dev/null || true

rm -rf /tmp/*

if [[ $SCRIPT_FAIL -gt 0 ]]; then
    echo "WARNING: $SCRIPT_FAIL script(s) had errors — check /var/log/cloudws-build.log"
fi
