#!/bin/bash
# CloudWS v0.1.8 — 35-init-service: Bridge to Unified Role Engine
# This script ensures cloudws-role.service is correctly enabled.
# The actual logic lives in /usr/libexec/cloudws/role-apply (system_files overlay).
set -euo pipefail

log() { echo "[35-init-service] $*"; }

log "Enabling unified system initialization..."

# Units are now delivered via system_files overlay.
systemctl enable cloudws-role.service 2>/dev/null || true
systemctl enable cloudws-podman-gc.timer 2>/dev/null || true

log "Initialization system services enabled."
