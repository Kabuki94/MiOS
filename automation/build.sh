#!/bin/bash
# MiOS 0.1.3 — Master build runner
# Executes all numbered scripts in order with unified status reporting.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
register_common_masks

export PACKAGES_MD="${PACKAGES_MD:-/ctx/PACKAGES.md}"
BUILD_LOG_DIR="/usr/lib/mios/logs"
mkdir -p "$BUILD_LOG_DIR"
BUILD_LOG="${BUILD_LOG_DIR}/build.log"
STATE_DIR="/tmp/mios-build-state"
mkdir -p "$STATE_DIR"

# Clear previous state
rm -f "$STATE_DIR"/*

# Unified logging: redirect sub-scripts to log file
exec 3>&1
exec > >(mask_filter >> "$BUILD_LOG") 2>&1

log_ts() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# v0.1.3: Normalize version to avoid vv prefixes
VERSION_RAW="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || cat /ctx/VERSION 2>/dev/null || echo '0.1.3')"
# Strip "MiOSv" or "v" if present
VERSION_STR=$(echo "$VERSION_RAW" | sed 's/^MiOSv//;s/^v//')

# ── Status Card Rendering ───────────────────────────────────────────────────
# Note: Removed cursor movement codes to prevent log duplication in non-TTY builds.
render_status_card() {
    local phase="$1"
    local current="$2"
    local total="$3"
    
    local ok_count=$(ls "$STATE_DIR"/*.ok 2>/dev/null | wc -l)
    local warn_count=$(ls "$STATE_DIR"/*.warn 2>/dev/null | wc -l)
    local fail_count=$(ls "$STATE_DIR"/*.fail 2>/dev/null | wc -l)

    {
        echo ""
        echo "┌───────────────────────────────────────────────────────────────────────────┐"
        printf "│ BUILDING: %-30s MiOS %-10s [%3d/%-3d] │\n" "$phase" "$VERSION_STR" "$current" "$total"
        echo "├───────────────────────────────────────────────────────────────────────────┤"
        printf "│  STATUS:  %-10s |  SUCCESS: %-4d |  WARN: %-4d |  FAIL: %-4d  │\n" \
            "$( [[ $fail_count -eq 0 ]] && echo "HEALTHY" || echo "DEGRADED" )" \
            "$ok_count" "$warn_count" "$fail_count"
        echo "└───────────────────────────────────────────────────────────────────────────┘"
    } >&3
}

# Print minimal start message
echo "==> MiOS ${VERSION_STR}: Build starting..." >&3

if [[ ! -f "$PACKAGES_MD" ]]; then
    echo "FATAL: $PACKAGES_MD not found." >&3
    exit 1
fi

# ── Execute numbered scripts ────────────────────────────────────────────────
# All numbered scripts in automation/ are intended for the orchestrator.
# 08-system-files-overlay.sh is run explicitly in Containerfile stage 1.
CONTAINERFILE_SCRIPTS="08-system-files-overlay.sh"

TOTAL_START=$SECONDS
ALL_SCRIPTS=("$SCRIPT_DIR"/[0-9][0-9]-*.sh)

# Calculate true total scripts
TOTAL_SCRIPTS=0
for script in "${ALL_SCRIPTS[@]}"; do
    SCRIPT_NAME="$(basename "$script")"
    if ! echo "$CONTAINERFILE_SCRIPTS" | grep -qF "$SCRIPT_NAME"; then
        TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
    fi
done

ITER=0
for script in "${ALL_SCRIPTS[@]}"; do
    SCRIPT_NAME="$(basename "$script")"
    if echo "$CONTAINERFILE_SCRIPTS" | grep -qF "$SCRIPT_NAME"; then
        continue
    fi
    ITER=$((ITER + 1))
    
    render_status_card "$SCRIPT_NAME" "$ITER" "$TOTAL_SCRIPTS"

    STEP_START=$SECONDS
    set +e
    export MIOS_BUILD_STATE="$STATE_DIR"
    bash "$script" >> "$BUILD_LOG" 2>&1
    SCRIPT_EXIT=$?
    set -e

    if [[ $SCRIPT_EXIT -eq 0 ]]; then
        touch "$STATE_DIR/${SCRIPT_NAME}.ok"
    else
        touch "$STATE_DIR/${SCRIPT_NAME}.fail"
    fi
done

# Final Card Update
render_status_card "FINISHING" "$ITER" "$TOTAL_SCRIPTS"

# ── Bloat Removal ──────────
log_ts "==> Removing known bloat packages..."
BLOAT_PACKAGES=$(source "${SCRIPT_DIR}/lib/packages.sh"; get_packages "bloat")
if [[ -n "$BLOAT_PACKAGES" ]]; then
    $DNF_BIN "${DNF_SETOPT[@]}" remove -y "${DNF_OPTS[@]}" $BLOAT_PACKAGES >> "$BUILD_LOG" 2>&1 || true
fi

# ── Cleanup ─────────────────────────────────────────────────────────────────
log_ts "==> Final build cleanup..."
rm -rf /var/cache/dnf/* /var/cache/libdnf5/*

# ── Artifact Unification: Snapshot Repository State ─────────────────────────
if [[ -d "/ctx" ]]; then
    log_ts "==> Creating repository artifact snapshot..."
    ARTIFACT_DIR="/usr/lib/mios/artifacts" # @track:PATH_ARTIFACTS
    mkdir -p "$ARTIFACT_DIR"
    tar -cJf "${ARTIFACT_DIR}/repo-snapshot.tar.xz" -C /ctx . 2>/dev/null || true
fi

TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
MIN=$(( TOTAL_ELAPSED / 60 ))
SEC=$(( TOTAL_ELAPSED % 60 ))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  FINAL BUILD SUMMARY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                          MiOS BUILD SUMMARY                               ║"
echo "╠═══════════════════════════════════════════════════════════════════════════╣"
echo "  Version:    ${VERSION_STR}"
echo "  Duration:   ${MIN}m ${SEC}s"
echo "  Steps:      ${ITER} executed"

FAIL_COUNT=$(ls "$STATE_DIR"/*.fail 2>/dev/null | wc -l)
if [[ $FAIL_COUNT -eq 0 ]]; then
echo "  Status:     COMPLETE ✅"
else
FAIL_LIST=$(ls "$STATE_DIR"/*.fail 2>/dev/null | xargs -n1 basename | sed 's/\.fail//' | tr '\n' ' ')
echo "  Failures:   ${FAIL_LIST}"
echo "  Status:     FAILED ❌"
fi
echo "  Log File:   ${BUILD_LOG}"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""
} >&3

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
