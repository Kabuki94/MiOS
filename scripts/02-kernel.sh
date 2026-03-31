#!/bin/bash
# CloudWS — 02-kernel: Kernel upgrade + development headers for akmods
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

install_packages_strict "kernel"

KVER=$(ls /lib/modules | sort -V | tail -n 1)
echo "[02-kernel] Native Fedora Rawhide kernel secured: $KVER"
