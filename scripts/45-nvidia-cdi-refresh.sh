#!/usr/bin/bash
# 45-nvidia-cdi-refresh.sh - wire up NVIDIA CDI auto-refresh services.
# Package installs moved to PACKAGES.md (packages-gpu-nvidia).
set -euo pipefail

log() { printf '[45-nvidia-cdi] %s\n' "$*"; }

# Toolkit-shipped units (require nvidia-container-toolkit >= 1.18)
systemctl enable nvidia-cdi-refresh.path    2>/dev/null || log "note: nvidia-cdi-refresh.path not available"
systemctl enable nvidia-cdi-refresh.service 2>/dev/null || true
systemctl enable nvidia-persistenced.service 2>/dev/null || true

# CloudWS detection shim (handles WSL /dev/dxg vs bare metal vs no-GPU VM)
systemctl enable cloudws-cdi-detect.service 2>/dev/null || log "WARN: cloudws-cdi-detect.service missing from system_files"

log "CDI refresh pipeline wired"