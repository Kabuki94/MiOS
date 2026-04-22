#!/bin/bash
# CloudWS v0.1.8 — 34-gpu-detect: Bridge to GPU detection service
# Blocks NVIDIA modules in VMs, enables hardware renderer on bare metal,
# detects RTX 50-series VFIO reset bug.
# Actual logic lives in /usr/libexec/cloudws/gpu-detect (system_files overlay).
set -euo pipefail

echo "[34-gpu-detect] Configuring GPU auto-detect service..."

# Unit and script are delivered via system_files overlay.
# Enablement is handled via system_files/usr/lib/systemd/system-preset/90-cloudws.preset

echo "[34-gpu-detect] GPU detection service enabled."
