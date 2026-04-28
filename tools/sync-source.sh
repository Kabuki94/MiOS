#!/bin/bash
# MiOS Source Sync  Unified Repository Synchronization
# Ensures build environment is synced with latest upstream.
set -euo pipefail

MIOS_SRC_DIR="/usr/src/mios"
REPO_URL="https://github.com/Kabuki94/MiOS-bootstrap.git"

echo "[RUN]  Synchronizing MiOS source..."

if [[ -d "${MIOS_SRC_DIR}/.git" ]]; then
    echo "  - Updating existing repo at $MIOS_SRC_DIR"
    cd "$MIOS_SRC_DIR"
    # Suppress output unless error
    git pull --rebase --quiet
else
    echo "  - Cloning repo to $MIOS_SRC_DIR"
    # Ensure parent directory exists and is writable
    mkdir -p "$(dirname "$MIOS_SRC_DIR")"
    git clone --quiet "$REPO_URL" "$MIOS_SRC_DIR"
fi

cd "$MIOS_SRC_DIR"
VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
echo "[OK] MiOS source synced: ${VERSION}"
