#!/bin/bash
# CloudWS v2.3.4 — 35-init-service: Bridge to Unified Role Engine
# This script ensures cloudws-role.service is correctly wired to role-apply.
set -euo pipefail

log() { echo "[35-init-service] $*"; }

log "Wiring unified system initialization..."

# 1. Install cloudws-role.service (the every-boot engine)
# The actual logic lives in /usr/libexec/cloudws/role-apply (shipped via system_files)
cat > /usr/lib/systemd/system/cloudws-role.service <<'EOSVC'
[Unit]
Description=CloudWS System Init & Role Engine
Wants=network-online.target
After=network-online.target local-fs.target
DefaultDependencies=no
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws/role-apply
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOSVC

# 2. Wire Podman garbage collection (moved from 35-init-service legacy)
cat > /usr/lib/systemd/system/cloudws-podman-gc.timer <<'EOTMR'
[Unit]
Description=Weekly Podman Cleanup
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
EOTMR

cat > /usr/lib/systemd/system/cloudws-podman-gc.service <<'EOSVC'
[Unit]
Description=CloudWS Podman Garbage Collection
[Service]
Type=oneshot
ExecStart=/usr/bin/podman system prune -a -f
EOSVC

# 3. Enable services
systemctl enable cloudws-role.service 2>/dev/null || true
systemctl enable cloudws-podman-gc.timer 2>/dev/null || true

log "Initialization system wired successfully."
