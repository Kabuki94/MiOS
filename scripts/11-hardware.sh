#!/bin/bash
# CloudWS v2.0 — 11-hardware: GPU drivers (Mesa + ROCm)
#
# NVIDIA: Handled by ucore-hci:stable-nvidia base image.
# Pre-signed with ublue MOK — no akmod build needed, SecureBoot works.
# nvidia-container-toolkit + CDI + SELinux policy already included.
#
# This script only handles Mesa (AMD/Intel) and optional ROCm.
# If NVIDIA kmod needs rebuilding after Rawhide distro-sync, we detect and do it.
#
# CHANGELOG v2.0:
#   - NVIDIA akmod removed (ucore base provides pre-signed modules)
#   - Post-distro-sync NVIDIA kmod rebuild if needed
#   - Mesa 26: ACO default shader compiler for RadeonSI
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

KVER=$(cat /tmp/cloudws-kver 2>/dev/null || ls -1 /lib/modules/ | sort -V | tail -1)

# ── Mesa (AMD / Intel / software fallback) ──────────────────────────────────
echo "[11-hardware] Installing Mesa GPU stack..."
install_packages_strict "gpu-mesa"

# ── AMD ROCm (fault-tolerant) ───────────────────────────────────────────────
echo "[11-hardware] Installing ROCm (optional)..."
install_packages "gpu-amd-compute"

# ── Intel GPU Compute (fault-tolerant — may not be on all architectures) ──
echo "[11-hardware] Installing Intel compute runtime (fault-tolerant)..."
install_packages "gpu-intel-compute" || true

# ── NVIDIA: Verify ucore's pre-signed modules survived distro-sync ──────────
echo "[11-hardware] Checking NVIDIA modules from ucore base..."
if [[ -d "/lib/modules/$KVER/extra/nvidia" ]] || \
   [[ -d "/lib/modules/$KVER/extra/nvidia-open" ]] || \
   modinfo nvidia -k "$KVER" &>/dev/null; then
    echo "[11-hardware] ✓ NVIDIA kmod present for kernel $KVER (ucore pre-signed)"
else
    echo "[11-hardware] NVIDIA kmod missing for $KVER — attempting akmod rebuild..."
    # Rawhide distro-sync may have upgraded the kernel past ucore's pre-built kmod.
    # Fall back to akmod build. The ublue MOK should still sign it.
    install_packages "gpu-nvidia"
    if command -v akmods &>/dev/null; then
        akmods --force --kernels "$KVER" 2>/dev/null || true
        if modinfo nvidia -k "$KVER" &>/dev/null; then
            echo "[11-hardware] ✓ NVIDIA kmod rebuilt for $KVER"
        else
            echo "[11-hardware] ⚠ NVIDIA kmod rebuild may have failed for $KVER"
        fi
    fi
fi

# Regenerate CDI spec if nvidia-ctk is available
if command -v nvidia-ctk &>/dev/null; then
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null || true
    echo "[11-hardware] NVIDIA CDI spec generated"
fi

# ── NVIDIA Open Kernel Module Configuration ─────────────────────────────────
cat > /etc/modprobe.d/nvidia-open.conf <<'EONVOPEN'
# CloudWS v2.0: Prefer NVIDIA open kernel modules (default for Turing+)
# Blackwell (RTX 50): open modules are the ONLY option.
options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
EONVOPEN

echo "[11-hardware] GPU stack complete. Mesa + NVIDIA (ucore pre-signed) + ROCm (optional)."
