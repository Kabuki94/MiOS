#!/bin/bash
# CloudWS — 11-hardware: Universal GPU drivers (AMD + Intel + NVIDIA)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# Mesa GPU drivers (AMD / Intel / software fallback)
install_packages_strict "gpu-mesa"

# ROCm OpenCL / HIP for AMD compute workloads (fault-tolerant)
install_packages "gpu-amd-compute" 2>/dev/null || true

# NVIDIA dGPU (akmod — builds kmod at image time for any NVIDIA card)
install_packages "gpu-nvidia"

# Build NVIDIA kmod against the highest installed kernel
KVER=$(ls /lib/modules | sort -V | tail -n 1)
echo "[11-hardware] Building NVIDIA kmod for kernel: $KVER"
akmods --force --kernels "$KVER"

# Generate CDI spec for GPU containers (Podman + Kubernetes)
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.json 2>/dev/null || true

echo "[11-hardware] Universal GPU drivers (Mesa + NVIDIA akmod) + NTSync + VFIO initialized on $KVER."
