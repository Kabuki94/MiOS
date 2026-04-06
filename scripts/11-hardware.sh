#!/bin/bash
# CloudWS v1.3 — 11-hardware: Universal GPU drivers + GPU-PV baseline (ALL images)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ─── GPU-PV Baseline (UNCONDITIONAL — every image format) ────────────────────
# This is the foundation for GPU acceleration in ALL deployment targets:
# - Bare metal: full Mesa + hardware Vulkan
# - WSL2: mesa-d3d12 (WDDM → Gallium bridge via dxgkrnl)
# - Hyper-V/QEMU VMs: virglrenderer (virtio-gpu 3D acceleration)
# - Containers/Pods: EGL/GLES for headless GPU compute
# - ISO installer: basic rendering during install
echo "[11-hardware] Installing GPU-PV baseline (all deployment targets)..."
install_packages_strict "gpu-pv-baseline"

# ─── Mesa GPU drivers (AMD / Intel / software fallback) ──────────────────────
install_packages_strict "gpu-mesa"

# ─── ROCm OpenCL / HIP for AMD compute workloads (fault-tolerant) ────────────
install_packages "gpu-amd-compute" 2>/dev/null || true

# ─── NVIDIA dGPU (akmod — builds kmod at image time for any NVIDIA card) ─────
install_packages "gpu-nvidia"

# Build NVIDIA kmod against the highest installed kernel
KVER=$(ls /lib/modules | sort -V | tail -n 1)
echo "[11-hardware] Building NVIDIA kmod for kernel: $KVER"
akmods --force --kernels "$KVER"

# Generate CDI spec for GPU containers (Podman + Kubernetes)
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.json 2>/dev/null || true

echo "[11-hardware] GPU-PV baseline + Mesa + NVIDIA akmod + CDI initialized on $KVER."
