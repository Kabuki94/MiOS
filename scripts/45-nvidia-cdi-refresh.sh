#!/usr/bin/bash
# 45-nvidia-cdi-refresh.sh - wire up runtime CDI spec generation
# Do NOT generate at build time - no GPU, and WSL vs bare-metal differ.
set -euo pipefail

log() { printf '[45-nvidia-cdi] %s\n' "$*"; }

# Ensure toolkit is present (ucore-hci already has it; fedora-bootc may not)
dnf5 -y install nvidia-container-toolkit nvidia-container-toolkit-base \
                nvidia-container-selinux || \
    log "WARN: nvidia-container-toolkit install partial (may already be present)"

# Enable the .path watcher + service (shipped by toolkit >= 1.18)
systemctl enable nvidia-cdi-refresh.path    2>/dev/null || log "WARN: nvidia-cdi-refresh.path not shipped; fallback to cloudws-cdi-detect"
systemctl enable nvidia-cdi-refresh.service 2>/dev/null || true
systemctl enable nvidia-persistenced.service 2>/dev/null || true

# Always enable our detection shim (handles WSL /dev/dxg case and bare-metal)
systemctl enable cloudws-cdi-detect.service

log "CDI refresh pipeline configured"