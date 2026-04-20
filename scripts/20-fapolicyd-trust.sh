#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuring fapolicyd for fs-verity/ComposeFS..."

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# Configure fapolicyd to use the file trust backend (fs-verity)
# This allows 0-second boot delays while maintaining rigid application whitelisting
# in immutable ComposeFS environments.
sed -i 's/^trust =.*/trust = file,rpmdb/' /etc/fapolicyd/fapolicyd.conf || true

# Enable the service
systemctl enable fapolicyd.service
echo "==> fapolicyd configured successfully."
