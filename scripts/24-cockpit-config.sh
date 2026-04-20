#!/usr/bin/env bash
set -eoux pipefail

echo "==> Configuring Cockpit for Container & WSL2 Reachability..."

# Ensure Cockpit allows unencrypted HTTP connections so Podman Desktop's
# 'Open in Browser' link works seamlessly over local port forwarding
# without triggering strict TLS/HTTPS browser rejections.
mkdir -p /etc/cockpit
cat << 'EOF' > /etc/cockpit/cockpit.conf
[WebService]
AllowUnencrypted = true
EOF
