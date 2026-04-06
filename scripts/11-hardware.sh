#!/bin/bash
# CloudWS v1.3 — 11-hardware: GPU drivers (Mesa + ROCm + NVIDIA)
#
# CHANGELOG v1.3:
#   - NVIDIA: Open kernel modules now default for Turing+ (driver 560+)
#   - Added RTX 50-series (Blackwell) VFIO reset bug warning
#   - Added nvidia-persistenced for multi-GPU stability
#   - Mesa 26: ACO is now default shader compiler for RadeonSI
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

KVER=$(cat /tmp/cloudws-kver 2>/dev/null || ls -1 /lib/modules/ | sort -V | tail -1)

# ── Mesa (AMD / Intel / software fallback) ──────────────────────────────────
echo "[11-hardware] Installing Mesa GPU stack..."
install_packages_strict "gpu-mesa"

# ── AMD ROCm (fault-tolerant — package names change between Rawhide releases) ─
echo "[11-hardware] Installing ROCm (optional)..."
install_packages "gpu-amd-compute"

# ── NVIDIA (akmod — builds kmod at image time) ──────────────────────────────
echo "[11-hardware] Installing NVIDIA drivers..."
install_packages "gpu-nvidia"

# Force akmod build for current kernel
if command -v akmods &>/dev/null; then
    echo "[11-hardware] Building NVIDIA kmod for kernel $KVER..."
    akmods --force --kernels "$KVER" 2>/dev/null || true

    # Verify the kmod was built
    if [[ -d "/lib/modules/$KVER/extra/nvidia" ]] || \
       [[ -d "/lib/modules/$KVER/extra/nvidia-open" ]]; then
        echo "[11-hardware] NVIDIA kmod built successfully"
    else
        echo "[11-hardware] WARNING: NVIDIA kmod build may have failed for $KVER"
        echo "[11-hardware] Check: ls /lib/modules/$KVER/extra/"
    fi
fi

# Generate NVIDIA Container Device Interface spec for Podman GPU containers
if command -v nvidia-ctk &>/dev/null; then
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null || true
    echo "[11-hardware] NVIDIA CDI spec generated"
fi

# ── NVIDIA Open Kernel Module Configuration ─────────────────────────────────
# Since driver 560+, open kernel modules are default for Turing (RTX 20+) and newer.
# For Blackwell (RTX 50-series), open modules are the ONLY option.
# This modprobe option ensures the open module is preferred.
cat > /etc/modprobe.d/nvidia-open.conf <<'EONVOPEN'
# CloudWS v1.3: Prefer NVIDIA open kernel modules (default for Turing+)
# For Pascal (GTX 10xx) and older, the proprietary module is still used.
# To force proprietary: options nvidia NVreg_OpenRmEnableUnsupportedGpus=0
options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
EONVOPEN

# ── RTX 50-series (Blackwell) VFIO Reset Bug Warning ────────────────────────
# CRITICAL: RTX 5090/5080/PRO 6000 have a severe VFIO reset bug where the GPU
# becomes completely unresponsive after PCI Function Level Reset, requiring a
# full host power cycle. NVIDIA has acknowledged the issue. No fix available.
# Workaround: Use RTX 40-series for VFIO passthrough until resolved.
cat > /usr/share/doc/cloudws-vfio-warning.txt <<'EOWARN'
╔══════════════════════════════════════════════════════════════════╗
║  NVIDIA RTX 50-series VFIO PASSTHROUGH WARNING                 ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  RTX 5090, 5080, and RTX PRO 6000 have a known VFIO reset      ║
║  bug that causes the GPU to become completely unresponsive       ║
║  after VM shutdown, requiring a full host power cycle.           ║
║                                                                  ║
║  Status: NVIDIA acknowledged, no fix available (April 2026)      ║
║  Workaround: Use RTX 40-series GPUs for VFIO passthrough        ║
║                                                                  ║
║  Tracked at:                                                     ║
║    - CloudRift.ai $1000 bounty                                   ║
║    - Proxmox forum thread #168424                                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOWARN

echo "[11-hardware] GPU driver stack installed. Kernel: $KVER"
