#!/bin/bash
# CloudWS v0.1.8 — 34-gpu-detect: Bridge to GPU detection service
# Blocks NVIDIA modules in VMs, enables hardware renderer on bare metal,
# detects RTX 50-series VFIO reset bug.
# Actual logic lives in /usr/libexec/cloudws/gpu-detect (system_files overlay).
set -euo pipefail

echo "[34-gpu-detect] Enabling GPU auto-detect service..."

# Unit and script are now delivered via system_files overlay.
# We only handle the enablement here for late-stage build consistency.
systemctl enable cloudws-gpu-detect.service 2>/dev/null || true

echo "[34-gpu-detect] GPU detection service enabled."
