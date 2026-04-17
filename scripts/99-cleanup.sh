#!/bin/bash
# CloudWS v2.1.1 — 99-cleanup: Final image cleanup (mirrors ucore/cleanup.sh)
#
# MANDATORY for bootc images. Every ublue-os image runs this pattern.
# Without it, BIB deployment fails or the booted system has broken /var state.
#
# v2.1.1: Added targeted lint cleanup for dnf5.log, ldconfig aux-cache,
# and any stray files in /var that trigger bootc container lint warnings.
#
# Reference: https://github.com/ublue-os/ucore/blob/main/cleanup.sh
set -euo pipefail

echo "[99-cleanup] Running final image cleanup..."

# 1. Clean /boot — BIB generates fresh bootloader, stale content causes conflicts
echo "[99-cleanup] Cleaning /boot..."
find /boot/ -maxdepth 1 -mindepth 1 -exec rm -fr {} \; || true

# 2. Clean /var — bootc treats /var as persistent state (like Docker VOLUME)
# Content in /var is only unpacked on FIRST install — never updated by bootc update.
echo "[99-cleanup] Cleaning /var (preserving cache)..."
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \; 2>/dev/null || true
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \; 2>/dev/null || true

# 3. Lint-specific cleanup: remove files that trigger bootc container lint warnings
echo "[99-cleanup] Cleaning lint triggers..."
rm -f /var/log/*.log /var/log/lastlog 2>/dev/null || true
rm -f /var/log/dnf5.log* 2>/dev/null || true
rm -rf /var/cache/ldconfig 2>/dev/null || true
rm -f /var/lib/systemd/random-seed 2>/dev/null || true

# 4. Clean /tmp
echo "[99-cleanup] Cleaning /tmp..."
find /tmp/* -maxdepth 0 -exec rm -fr {} \; 2>/dev/null || true

# 5. ostree container commit — CRITICAL: finalizes OSTree layer metadata
echo "[99-cleanup] Running ostree container commit..."
ostree container commit 2>&1 || true

# 6. Recreate /var/tmp (required by systemd)
echo "[99-cleanup] Recreating /var/tmp..."
mkdir -p /var/tmp
chmod 1777 /var/tmp

# 7. Clean DNF caches
echo "[99-cleanup] Cleaning package manager caches..."
dnf clean all 2>/dev/null || true

echo "[99-cleanup] ✓ Image cleanup complete"
