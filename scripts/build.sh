#!/bin/bash
# CloudWS v2.0 — Master build runner
# Executes all numbered scripts in order, then cleans up.
# Called from Containerfile RUN layer via bind mount.
#
# CHANGELOG v2.0:
#   - FIX: install_weakdeps=False (was True in v1.3 — contradicted docs)
#   - FIX: Safe arithmetic: VAR=$((VAR + 1)) not ((VAR++)) (set -e compat)
#   - Base: ucore-hci:stable-nvidia (Rawhide overlay in 01-repos.sh)
#   - Post-build validates malcontent-libs present (flatpak needs it)
#   - Footgun list includes malcontent-control/pam/tools
#   - PackageKit/gnome-tour removed via dnf (safe, no cascade)
#   - gnome-software KEPT (manages Flatpaks on immutable systems)
#   - malcontent-control hidden via NoDisplay (dnf remove cascades)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PACKAGES_MD="${PACKAGES_MD:-/ctx/PACKAGES.md}"
BUILD_LOG="/tmp/cloudws-build.log"

exec > >(tee -a "$BUILD_LOG") 2>&1

log_ts() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

VERSION_STR="$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || cat /ctx/VERSION 2>/dev/null || echo '2.0.0')"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS v${VERSION_STR} — Building OS Image               ║"
echo "║  Base: ucore-hci:stable-nvidia + F44 + Rawhide kernel    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log_ts "Build started"
log_ts "PACKAGES.MD : $PACKAGES_MD"
log_ts "SCRIPT_DIR  : $SCRIPT_DIR"
echo ""

if [[ ! -f "$PACKAGES_MD" ]]; then
    log_ts "FATAL: $PACKAGES_MD not found. Build context missing."
    exit 1
fi

# ── DNF config ──────────────────────────────────────────────────────────────
# FIX v2.0: was True in v1.3 — both docs say False is "non-negotiable"
export DNF_SETOPT="--setopt=install_weak_deps=False"
export SYSTEMD_OFFLINE=1
export container=podman

# ── Execute numbered scripts ────────────────────────────────────────────────
# Scripts 18/19/20-fapolicyd/21/22 are called explicitly by the Containerfile
# AFTER this script completes. Skip them here to prevent double-execution.
CONTAINERFILE_SCRIPTS="18-apply-boot-fixes.sh 19-k3s-selinux.sh 20-fapolicyd-trust.sh 21-moby-engine.sh 22-freeipa-client.sh 23-uki-render.sh 24-cockpit-config.sh 25-firewall-ports.sh"

TOTAL_START=$SECONDS
SCRIPT_COUNT=0
SCRIPT_FAIL=0

for script in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
    SCRIPT_NAME="$(basename "$script")"
    if echo "$CONTAINERFILE_SCRIPTS" | grep -qF "$SCRIPT_NAME"; then
        log_ts "==> Skipping (Containerfile post-step): $SCRIPT_NAME"
        continue
    fi
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log_ts "==> Running: $SCRIPT_NAME"
    echo "═══════════════════════════════════════════════════════════════"

    STEP_START=$SECONDS

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

# ── Suppress ucore base bloat (build-up approach — no dnf remove) ──────────
# Per §3.9: dnf remove is never needed; mask services and add NoDisplay instead.
# PackageKit: mask the daemon so it never runs
# gnome-tour / gnome-initial-setup: hide via NoDisplay=true desktop entries
echo ""
log_ts "==> Suppressing base image bloat (mask/hide, not remove)..."
systemctl mask packagekit.service 2>/dev/null || true
for app in gnome-tour gnome-initial-setup; do
    desktop="/usr/share/applications/${app}.desktop"
    if [ -f "$desktop" ]; then
        mkdir -p /usr/local/share/applications
        grep -v '^NoDisplay=' "$desktop" > "/usr/local/share/applications/${app}.desktop"
        echo "NoDisplay=true" >> "/usr/local/share/applications/${app}.desktop"
        echo "  ✓ Hidden: $app (NoDisplay=true)"
    fi
done

# ── Post-build validation ──────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
log_ts "==> Post-build validation"
echo "═══════════════════════════════════════════════════════════════"

CRITICAL_PACKAGES=(
    gnome-shell gdm podman bootc libvirt kernel firewalld cockpit
    NetworkManager pipewire tuned chrony openssh-server
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

# malcontent-libs MUST be present (flatpak links against libmalcontent-0.so.0)
if rpm -q malcontent-libs > /dev/null 2>&1; then
    echo "  ✓ malcontent-libs (required by flatpak)"
else
    echo "  ⚠ malcontent-libs MISSING — flatpak may break"
fi

# gnome-software: expected (manages Flatpaks on immutable systems)
if rpm -q gnome-software > /dev/null 2>&1; then
    echo "  ✓ gnome-software (Flatpak manager)"
fi

# Footgun check — these should NOT be present after bloat removal
FOOTGUN_PACKAGES=(
    PackageKit gnome-initial-setup gnome-tour
    malcontent-pam malcontent-tools
)
for pkg in "${FOOTGUN_PACKAGES[@]}"; do
    if rpm -q "$pkg" > /dev/null 2>&1; then
        echo "  ⚠ FOOTGUN: $pkg is installed (should not be in build-up image)"
    fi
done

if [[ $VALIDATION_FAIL -gt 0 ]]; then
    log_ts "WARNING: $VALIDATION_FAIL critical packages missing!"
fi

# ── Cleanup ─────────────────────────────────────────────────────────────────

# Create sysusers.d entry for cloudws user (fixes bootc lint sysusers warning)
mkdir -p /usr/lib/sysusers.d
cat > /usr/lib/sysusers.d/cloudws.conf <<'EOF'
u cloudws - "CloudWS User" /home/cloudws /bin/bash
EOF

echo ""
log_ts "Cleaning up..."
dnf clean all
rm -rf /var/cache/dnf /var/cache/libdnf5 /tmp/geist-font /tmp/*.tar* /tmp/*.rpm 2>/dev/null || true
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
rm -rf /usr/share/gnome/help/* /usr/share/help/* 2>/dev/null || true

# Clean bootc lint triggers
rm -f /var/log/dnf5.log* /var/log/cloudws-build.log 2>/dev/null || true
rm -rf /run/ceph /run/cockpit /run/k3s /tmp/* 2>/dev/null || true
rm -f /var/lib/systemd/random-seed 2>/dev/null || true

rm -f /tmp/cloudws-build.log

# ── Summary ─────────────────────────────────────────────────────────────────
TOTAL_ELAPSED=$(( SECONDS - TOTAL_START ))
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  BUILD COMPLETE                                            ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Base:      ucore-hci:stable-nvidia + F44 + Rawhide kernel  ║"
echo "║  Scripts:   $SCRIPT_COUNT executed, $SCRIPT_FAIL failed"
echo "║  Packages:  $VALIDATION_FAIL critical missing"
echo "║  Duration:  ${TOTAL_ELAPSED}s ($((TOTAL_ELAPSED / 60))m $((TOTAL_ELAPSED % 60))s)"
echo "║  Version:   $VERSION_STR"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ $SCRIPT_FAIL -gt 0 ]]; then
    log_ts "FATAL: $SCRIPT_FAIL scripts failed — review build output above"
    exit 1
fi
