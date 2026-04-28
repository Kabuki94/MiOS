#!/bin/bash
# MiOS Builder  Automatic ISO Generator
# This script is triggered by Ignition on first boot.
set -euo pipefail

LOG_FILE="/var/log/mios-builder.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "MiOS Builder  Starting Automatic Build"
echo "Timestamp: $(date -u)"
echo ""

# 1. Wait for network to be fully up
echo "[RUN] Waiting for network connectivity..."
until ping -c 1 github.com &>/dev/null; do
    echo "  - Network not ready, retrying..."
    sleep 5
done
echo "[OK] Network connected"

# 2. Ensure dependencies are present
echo "[RUN] Checking prerequisites..."
for pkg in git podman rsync; do
    if ! command -v "$pkg" &>/dev/null; then
        echo "  - Installing $pkg..."
        dnf install -y "$pkg"
    fi
done

# 3. Ensure 'just' is available
if ! command -v just &>/dev/null; then
    echo "[RUN] Installing 'just' task runner..."
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
fi

# 4. Bootstrap MiOS Build Environment
# This clones the repo to /usr/src/mios and sets up the integrated environment.
echo "[RUN] Bootstrapping MiOS..."
curl -sL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/install.sh | bash

# 5. Build Live ISO
MIOS_SRC="/usr/src/mios"
cd "$MIOS_SRC"
echo "[RUN] Building MiOS Live ISO..."

# Ensure podman is ready (system-level)
systemctl enable --now podman.socket

# Run the build via just
# The 'iso' target in Justfile handles 'podman build' and 'bootc-image-builder'
just iso

echo ""
echo "[OK] MiOS Build Complete"
echo "Artifact: ${MIOS_SRC}/output/mios-installer.iso"
echo ""
