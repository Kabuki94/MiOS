#!/bin/bash
# MiOS v0.1.1 — 35-init-service: Bridge to Unified Role Engine
# This script ensures mios-role.service is correctly enabled.
# The actual logic lives in /usr/libexec/mios/role-apply (system_files overlay).
set -euo pipefail

log() { echo "[35-init-service] $*"; }

log "Enabling unified system initialization..."

# Units are now delivered via system_files overlay.
systemctl enable mios-role.service 2>/dev/null || true
systemctl enable mios-podman-gc.timer 2>/dev/null || true

log "Initialization system services enabled."
