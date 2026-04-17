#!/bin/bash
# CloudWS v2.3.0 — 11-hardware: GPU drivers (Mesa + AMD ROCm + Intel + NVIDIA)
#
# NVIDIA strategy (v2.3.0 — maximum portability):
#   Primary:  ucore-hci:stable-nvidia base ships pre-signed kmods for the
#             base kernel. If they match `uname -r`, we use them directly.
#   Fallback: Containerfile COPY'd kernel-matched RPMs from
#             ghcr.io/ublue-os/akmods-nvidia-open:<flavor>-<fedora>-<nv>
#             into /ctx/nv-akmods/{open,common}/. When ucore's modules don't
#             match the running kernel (the 6.19.10 vs 6.19.12 mismatch that
#             blew up v2.2.x), we install the COPY'd RPMs which ARE
#             kernel-matched by the tag triple.
#   Runtime:  34-gpu-detect.sh picks whichever module set loads on the actual
#             host. Both sets are present and signed; modprobe selects.
#
# Mesa (AMD/Intel/software fallback) and ROCm + intel-compute-runtime are
# installed from PACKAGES.md. They have no kernel-version coupling.
#
# CHANGELOG:
#   v2.3.0: akmods-nvidia-open COPY-layer fallback; no more hard-fail when
#           base kernel-devel is missing from F44 repos.
#   v2.0:   NVIDIA akmod removed (ucore base provides pre-signed modules).
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

# ── NVIDIA: Verify ucore's pre-signed modules match the kernel ──────────────
echo "[11-hardware] Checking NVIDIA modules from ucore base (kernel=$KVER)..."

NVIDIA_PRESENT=0
if [[ -d "/lib/modules/$KVER/extra/nvidia" ]] || \
   [[ -d "/lib/modules/$KVER/extra/nvidia-open" ]] || \
   modinfo nvidia -k "$KVER" &>/dev/null; then
    echo "[11-hardware] ✓ NVIDIA kmod present for kernel $KVER (ucore pre-signed)"
    NVIDIA_PRESENT=1
fi

# ── NVIDIA fallback: install kernel-matched RPMs COPY'd from akmods-nvidia-open ──
# The Containerfile COPY'd pre-built, pre-signed kmod RPMs into /ctx/nv-akmods/.
# These are tagged against the EXACT kernel in ublue's akmods image, which
# should match the ucore-hci kernel because they share the ublue build pipeline.
# If ucore's in-image modules are absent or kernel-mismatched, install the
# COPY'd RPMs. They ship the same ublue MOK signature, so Secure Boot works.
if [[ $NVIDIA_PRESENT -eq 0 ]]; then
    echo "[11-hardware] No NVIDIA kmod for $KVER — trying COPY'd akmods-nvidia-open RPMs..."
    if [[ -d /ctx/nv-akmods/open ]] && compgen -G '/ctx/nv-akmods/open/*.rpm' > /dev/null; then
        # Common akmods provide the MOK certs + ublue-os-akmods-addons
        if [[ -d /ctx/nv-akmods/common ]] && compgen -G '/ctx/nv-akmods/common/*.rpm' > /dev/null; then
            echo "[11-hardware] Installing common akmod RPMs..."
            dnf -y install /ctx/nv-akmods/common/*.rpm --skip-unavailable 2>&1 | tail -5 || true
        fi
        echo "[11-hardware] Installing NVIDIA open kmod RPMs..."
        dnf -y install /ctx/nv-akmods/open/*.rpm --skip-unavailable 2>&1 | tail -10 || true

        if [[ -d "/lib/modules/$KVER/extra/nvidia-open" ]] || \
           [[ -d "/lib/modules/$KVER/extra/nvidia" ]] || \
           modinfo nvidia -k "$KVER" &>/dev/null; then
            echo "[11-hardware] ✓ NVIDIA kmod installed from akmods COPY layer for $KVER"
            NVIDIA_PRESENT=1
        else
            echo "[11-hardware] ⚠ akmods COPY layer RPMs didn't land a kmod for $KVER"
            echo "[11-hardware]    installed kmod-nvidia*: $(rpm -qa 'kmod-nvidia*' 2>/dev/null | tr '\n' ' ')"
        fi
    else
        echo "[11-hardware] ⚠ /ctx/nv-akmods/open/ empty or missing — COPY layer didn't work"
    fi
fi

# ── NVIDIA last-resort: akmod-nvidia from RPMFusion ─────────────────────────
# Only if ucore base AND COPY layer both missed. Requires kernel-devel-$KVER
# which triggered the v2.2.x failure. If kernel-devel is unavailable, we
# accept NVIDIA-less and let 34-gpu-detect.sh handle runtime blacklisting.
if [[ $NVIDIA_PRESENT -eq 0 ]]; then
    echo "[11-hardware] Last-resort: akmod-nvidia build against $KVER..."
    if install_packages "gpu-nvidia"; then
        if command -v akmods &>/dev/null; then
            akmods --force --kernels "$KVER" 2>&1 | tail -10 || true
            if modinfo nvidia -k "$KVER" &>/dev/null; then
                echo "[11-hardware] ✓ NVIDIA kmod rebuilt via akmods for $KVER"
                NVIDIA_PRESENT=1
            fi
        fi
    fi
fi

if [[ $NVIDIA_PRESENT -eq 0 ]]; then
    echo "[11-hardware] ⚠ No NVIDIA kmod for $KVER after all fallback attempts."
    echo "[11-hardware]    Image will ship without NVIDIA acceleration. Users with"
    echo "[11-hardware]    NVIDIA hardware should rebuild the kmod at runtime:"
    echo "[11-hardware]       sudo dnf install kernel-devel-\$(uname -r) akmod-nvidia"
    echo "[11-hardware]       sudo akmods --force --kernels \$(uname -r)"
fi

# Regenerate CDI spec if nvidia-ctk is available (fails gracefully in no-GPU builds)
if command -v nvidia-ctk &>/dev/null; then
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>/dev/null || true
    echo "[11-hardware] NVIDIA CDI spec generated (build-time; runtime refresh handled by nvidia-cdi-refresh.path)"
fi

# ── NVIDIA Open Kernel Module Configuration ─────────────────────────────────
# Turing+ (RTX 20xx and newer) supports open modules; RTX 50 Blackwell requires
# them. NVreg_OpenRmEnableUnsupportedGpus=1 lets open modules attempt older
# cards too (Pascal, Maxwell) where supported.
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nvidia-open.conf <<'EONVOPEN'
# CloudWS v2.3.0: Prefer NVIDIA open kernel modules (default for Turing+).
# Blackwell (RTX 50): open modules are the ONLY option.
options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
# Preserve video memory across suspend/hibernate. Required for nvidia-drm.
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EONVOPEN

echo "[11-hardware] GPU stack complete. Mesa + AMD ROCm + Intel + NVIDIA (ucore/akmods/rebuild)."
