#!/bin/bash
# CloudWS v1.3 — 02-kernel: Kernel + development headers
# Headers are required for akmod-nvidia to build kernel modules at image time.
#
# CHANGELOG v1.3:
#   - Added kernel-modules-core (split from kernel-modules in kernel 7.0)
#   - Added kernel version logging for build reproducibility
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

install_packages_strict "kernel"

# Capture KVER for akmod builds later.
# Multiple kernels may be installed; use the highest version.
export KVER=$(ls -1 /lib/modules/ | sort -V | tail -1)
echo "[02-kernel] Kernel version: $KVER"
echo "$KVER" > /tmp/cloudws-kver

# Verify kernel modules directory exists (build will fail without it)
if [[ ! -d "/lib/modules/$KVER" ]]; then
    echo "[02-kernel] FATAL: /lib/modules/$KVER does not exist"
    exit 1
fi

echo "[02-kernel] Kernel $KVER installed successfully."
