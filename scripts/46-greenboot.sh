#!/usr/bin/bash
# 46-greenboot.sh - health-check driven auto-rollback
set -euo pipefail

log() { printf '[46-greenboot] %s\n' "$*"; }

dnf5 -y install greenboot greenboot-default-health-checks || \
    log "WARN: greenboot install failed; skipping"

# Enable core greenboot services
for unit in greenboot-healthcheck.service \
            greenboot-rpm-ostree-grub2-check-fallback.service \
            greenboot-grub2-set-counter.service \
            greenboot-grub2-set-success.service \
            greenboot-status.service \
            redboot-auto-reboot.service
do
    systemctl enable "$unit" 2>/dev/null || true
done

# Ensure boot counter max
mkdir -p /etc/greenboot
cat > /etc/greenboot/greenboot.conf <<'EOF'
# CloudWS-bootc greenboot configuration
GREENBOOT_MAX_BOOTS=3
GREENBOOT_WATCHDOG_CHECK_ENABLED=false
EOF

chmod +x /etc/greenboot/check/required.d/*.sh 2>/dev/null || true
chmod +x /etc/greenboot/check/wanted.d/*.sh   2>/dev/null || true
chmod +x /etc/greenboot/green.d/*.sh          2>/dev/null || true
chmod +x /etc/greenboot/red.d/*.sh            2>/dev/null || true

log "greenboot configured"