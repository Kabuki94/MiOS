#!/bin/bash
# MiOS v0.1.3  11-hardware: GPU drivers (Mesa + AMD ROCm + Intel + NVIDIA)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"
source "${SCRIPT_DIR}/lib/common.sh"

KVER=$(cat /tmp/mios-kver 2>/dev/null || find /usr/lib/modules/ -mindepth 1 -maxdepth 1 -printf "%f\n" | sort -V | tail -1)
if [[ -z "$KVER" ]]; then
    echo "[11-hardware] ERROR: Could not detect kernel version. /tmp/mios-kver is missing and /usr/lib/modules/ is empty."
    exit 1
fi

# -- Mesa (AMD / Intel / software fallback) ----------------------------------
echo "[11-hardware] Installing Mesa GPU stack..."
# Ensure mesa-va-drivers-freeworld is available via RPMFusion
install_packages_strict "gpu-mesa"

# -- AMD ROCm (fault-tolerant) -----------------------------------------------
echo "[11-hardware] Installing ROCm (optional)..."
install_packages "gpu-amd-compute"

# -- Intel GPU Compute (fault-tolerant) --------------------------------------
echo "[11-hardware] Installing Intel compute runtime (fault-tolerant)..."
install_packages "gpu-intel-compute" || true

# -- NVIDIA: Verify ucore's pre-signed modules match the kernel --------------
echo "[11-hardware] Checking NVIDIA modules from ucore base (kernel=$KVER)..."

NVIDIA_PRESENT=0
if [[ -d "/usr/lib/modules/$KVER/extra/nvidia" ]] || \
   [[ -d "/usr/lib/modules/$KVER/extra/nvidia-open" ]] || \
   modinfo nvidia -k "$KVER" &>/dev/null; then
    echo "[11-hardware] [OK] NVIDIA kmod present for kernel $KVER (ucore pre-signed)"
    NVIDIA_PRESENT=1
fi

# -- NVIDIA fallback: akmod rebuild via RPMFusion ----------------------------
if [[ $NVIDIA_PRESENT -eq 0 ]]; then
    echo "[11-hardware] Fallback: akmod-nvidia build against $KVER..."
    # install_packages returns 0 even if it fails to install some packages
    install_packages "gpu-nvidia"
    if command -v akmods &>/dev/null; then
        echo "[11-hardware] Running akmods build for $KVER..."
        akmods --force --kernels "$KVER" 2>&1 | tail -10 || true
        if modinfo nvidia -k "$KVER" &>/dev/null; then
            echo "[11-hardware] [OK] NVIDIA kmod rebuilt via akmods for $KVER"
            NVIDIA_PRESENT=1
        fi
    fi
fi

if [[ $NVIDIA_PRESENT -eq 0 ]]; then
    echo "[11-hardware] [WARN] No NVIDIA kmod for $KVER after all fallback attempts."
    echo "[11-hardware]    Image will ship without NVIDIA acceleration."
fi

# Regenerate CDI spec if nvidia-ctk is available
if command -v nvidia-ctk &>/dev/null; then
    echo "[11-hardware] Generating NVIDIA CDI spec..."
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null || true
fi

echo "[11-hardware] GPU stack complete."
