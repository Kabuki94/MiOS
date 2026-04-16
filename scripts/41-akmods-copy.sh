#!/usr/bin/bash
# 41-akmods-copy.sh - install pre-signed NVIDIA + extra akmods from ublue-os
# Kernel modules signed against ublue-os MOK (akmods-ublue.der).
# Users enroll at first boot via `ujust enroll-mok`.
set -euo pipefail

log() { printf '[41-akmods-copy] %s\n' "$*"; }

NVIDIA_DIR=/tmp/akmods-nvidia
COMMON_DIR=/tmp/akmods-common
EXTRA_DIR=/tmp/akmods-extra

# --- NVIDIA open kmod + userspace ------------------------------------------
if compgen -G "${NVIDIA_DIR}/kmods/*.rpm" > /dev/null; then
    log "installing NVIDIA open akmod RPMs"
    dnf5 -y install \
        "${NVIDIA_DIR}"/kmods/*.rpm \
        "${NVIDIA_DIR}"/*.rpm 2>/dev/null || \
    dnf5 -y install "${NVIDIA_DIR}"/kmods/*.rpm
else
    log "WARN: no NVIDIA akmod RPMs found in ${NVIDIA_DIR}/kmods - skipping"
fi

# --- ublue akmods common addons (MOK cert + udev rules) --------------------
if compgen -G "${COMMON_DIR}/ublue-os-*.rpm" > /dev/null; then
    log "installing ublue-os akmod addons (MOK cert, udev rules)"
    dnf5 -y install \
        "${COMMON_DIR}"/ublue-os-akmods-addons-*.rpm \
        "${COMMON_DIR}"/ublue-os-nvidia-addons-*.rpm 2>/dev/null || true
fi

# --- extra: kvmfr (Looking Glass) ------------------------------------------
if compgen -G "${EXTRA_DIR}/kmods/kmod-kvmfr-*.rpm" > /dev/null; then
    log "installing kvmfr (Looking Glass) akmod"
    dnf5 -y install "${EXTRA_DIR}"/kmods/kmod-kvmfr-*.rpm || \
      log "WARN: kvmfr install failed (non-fatal, Looking Glass optional)"
fi

# --- MOK cert in the location users expect ---------------------------------
mkdir -p /etc/pki/akmods/certs
for crt in /usr/share/ublue-os/akmods/*.der /etc/pki/akmods/certs/*.der; do
    [[ -f "$crt" ]] || continue
    cp -a "$crt" /etc/pki/akmods/certs/ 2>/dev/null || true
done

log "akmods copy phase complete"