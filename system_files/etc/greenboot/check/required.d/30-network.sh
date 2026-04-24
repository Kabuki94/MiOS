#!/bin/bash
# CloudWS greenboot required check: DNS reachability to GHCR
# Failure causes greenboot to mark the boot as unhealthy → bootc rollback after
# GREENBOOT_MAX_BOOT_ATTEMPTS failed attempts.
set -euo pipefail

TIMEOUT=30
TARGET="ghcr.io"

echo "[greenboot/30-network] Checking DNS reachability to ${TARGET}..."

if systemd-resolve --timeout="${TIMEOUT}" "${TARGET}" >/dev/null 2>&1; then
    echo "[greenboot/30-network] OK — ${TARGET} resolves"
    exit 0
else
    echo "[greenboot/30-network] FAIL — cannot resolve ${TARGET} after ${TIMEOUT}s"
    exit 1
fi
