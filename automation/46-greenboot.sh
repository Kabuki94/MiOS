#!/usr/bin/bash
# 46-greenboot.sh - wire greenboot services; package installs via PACKAGES.md
# (packages-updater section: greenboot, greenboot-default-health-checks).
set -euo pipefail

log() { printf '[46-greenboot] %s\n' "$*"; }

# Enable core greenboot services
for unit in \
    greenboot-healthcheck.service \
    greenboot-rpm-ostree-grub2-check-fallback.service \
    greenboot-grub2-set-counter.service \
    greenboot-grub2-set-success.service \
    greenboot-status.service \
    redboot-auto-reboot.service
do
    systemctl enable "$unit" 2>/dev/null || log "note: $unit not installed"
done

# Make health-check scripts executable (shipped via overlay/)
# Directory creation and config installation moved to overlay/ overlay.
chmod +x /etc/greenboot/check/required.d/*.sh 2>/dev/null || true
chmod +x /etc/greenboot/check/wanted.d/*.sh   2>/dev/null || true
chmod +x /etc/greenboot/green.d/*.sh          2>/dev/null || true
chmod +x /etc/greenboot/red.d/*.sh            2>/dev/null || true

log "greenboot wired"
