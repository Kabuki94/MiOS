#!/usr/bin/bash
# 49-finalize.sh - final cleanup, systemd preset application, image linting
set -euo pipefail

log() { printf '[49-finalize] %s\n' "$*"; }

# Apply all shipped presets now (so `systemctl is-enabled` reflects intent)
systemctl preset-all 2>/dev/null || true

# Ensure role directory exists with example config
mkdir -p /etc/cloudws
if [[ ! -f /etc/cloudws/role.conf ]]; then
    cp -a /usr/share/cloudws/role.conf.example /etc/cloudws/role.conf 2>/dev/null || true
fi

# Trim dnf caches
dnf5 clean all || true
rm -rf /var/cache/libdnf5 /var/cache/dnf /var/log/dnf5.log* 2>/dev/null || true

# Set image metadata
mkdir -p /etc/cloudws
cat > /etc/cloudws/version <<EOF
CLOUDWS_VERSION=2.2.0
CLOUDWS_BASE=ucore-hci-stable-nvidia
CLOUDWS_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "finalize complete"