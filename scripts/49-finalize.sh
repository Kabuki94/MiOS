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

# Scrub potential credential leaks from build-time placeholder injections
log "scrubbing build-time credentials and override scripts"
rm -f /etc/containers/auth.json \
      /root/.docker/config.json \
      /root/.containers/auth.json \
      /ctx/scripts/99-overrides.sh \
      /usr/local/bin/99-overrides.sh \
      /usr/bin/99-overrides.sh 2>/dev/null || true

# Trim dnf caches
dnf5 clean all || true
rm -rf /var/cache/libdnf5 /var/cache/dnf /var/log/dnf5.log* 2>/dev/null || true

# Set image metadata
CLOUDWS_VERSION=$(cat /ctx/VERSION 2>/dev/null || echo "unknown")
mkdir -p /etc/cloudws
cat > /etc/cloudws/version <<EOF
CLOUDWS_VERSION=${CLOUDWS_VERSION}
CLOUDWS_BASE=ucore-hci-stable-nvidia
CLOUDWS_BUILT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "finalize complete"
