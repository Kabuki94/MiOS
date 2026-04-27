#!/bin/bash
# MiOS v0.1.3 — Master build runner
# Executes all numbered scripts in order, then cleans up.
# Called from Containerfile RUN layer via bind mount.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
register_common_masks
export PACKAGES_MD="${PACKAGES_MD:-/ctx/PACKAGES.md}"
BUILD_LOG="/tmp/mios-build-internal.log"

# Unified logging: redirect all output to log file, but keep high-level progress on stdout
# Use a descriptor for the real stdout to print the summary at the end
exec 3>&1
exec > >(mask_filter >> "$BUILD_LOG") 2>&1

log_ts() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

VERSION_STR="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || cat /ctx/VERSION 2>/dev/null || echo 'v0.1.3')"

# Print minimal start message to real stdout
echo "==> MiOS v${VERSION_STR}: Build started (Logging to ${BUILD_LOG})" >&3

if [[ ! -f "$PACKAGES_MD" ]]; then
    echo "FATAL: $PACKAGES_MD not found." >&3
    exit 1
fi

# ── DNF config ──────────────────────────────────────────────────────────────
export SYSTEMD_OFFLINE=1
export container=podman

# ── Execute numbered scripts ────────────────────────────────────────────────
CONTAINERFILE_SCRIPTS="08-system-files-overlay.sh 18-apply-boot-fixes.sh 19-k3s-selinux.sh 20-fapolicyd-trust.sh 21-moby-engine.sh 22-freeipa-client.sh 23-uki-render.sh 25-firewall-ports.sh 26-gnome-remote-desktop.sh 37-ai-agnostic.sh 37-flatpak-env.sh 37-ollama-prep.sh"

TOTAL_START=$SECONDS
SCRIPT_COUNT=0
SCRIPT_FAIL=0
FAILED_SCRIPTS=()

# Function to show a simple progress indicator
print_progress() {
    local current=$1
    local total=$2
    local name=$3
    # Use \r to overwrite line for a "bar" effect in some terminals
    printf "\r[MiOS Build] Step %d/%d: %-40s" "$current" "$total" "$name" >&3
}

ALL_SCRIPTS=("$SCRIPT_DIR"/[0-9][0-9]-*.sh)
TOTAL_SCRIPTS=${#ALL_SCRIPTS[@]}

for script in "${ALL_SCRIPTS[@]}"; do
    SCRIPT_NAME="$(basename "$script")"
    if echo "$CONTAINERFILE_SCRIPTS" | grep -qF "$SCRIPT_NAME"; then
        continue
    fi
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    
    print_progress "$SCRIPT_COUNT" "$TOTAL_SCRIPTS" "$SCRIPT_NAME"

    STEP_START=$SECONDS
    set +e
    bash "$script" >> "$BUILD_LOG" 2>&1
    SCRIPT_EXIT=$?
    set -e
    STEP_ELAPSED=$(( SECONDS - STEP_START ))

    if [[ $SCRIPT_EXIT -ne 0 ]]; then
        SCRIPT_FAIL=$((SCRIPT_FAIL + 1))
        FAILED_SCRIPTS+=("$SCRIPT_NAME")
    fi
done

# Clear progress line
printf "\r%-60s\r" "" >&3

# ── Bloat Removal ──────────
log_ts "==> Removing known bloat packages..."
BLOAT_PACKAGES=$(source "${SCRIPT_DIR}/lib/packages.sh"; get_packages "bloat")
if [[ -n "$BLOAT_PACKAGES" ]]; then
    $DNF_BIN "${DNF_SETOPT[@]}" remove -y "${DNF_OPTS[@]}" $BLOAT_PACKAGES >> "$BUILD_LOG" 2>&1 || true
fi

# ── Cleanup ─────────────────────────────────────────────────────────────────
log_ts "==> Final build cleanup..."
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /tmp/*

TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
MIN=$(( TOTAL_ELAPSED / 60 ))
SEC=$(( TOTAL_ELAPSED % 60 ))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  FINAL BUILD SUMMARY (Singular print at bottom)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                          MiOS BUILD SUMMARY                               ║"
echo "╠═══════════════════════════════════════════════════════════════════════════╣"
echo "  Version:    v${VERSION_STR}"
echo "  Duration:   ${MIN}m ${SEC}s"
echo "  Steps:      ${SCRIPT_COUNT} executed"
if [[ $SCRIPT_FAIL -eq 0 ]]; then
echo "  Status:     SUCCESS ✅"
else
echo "  Status:     FAILED ❌ ($SCRIPT_FAIL errors)"
echo "  Failures:   ${FAILED_SCRIPTS[*]}"
fi
echo "  Log File:   ${BUILD_LOG}"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""
} >&3

if [[ $SCRIPT_FAIL -gt 0 ]]; then
    exit 1
fi
