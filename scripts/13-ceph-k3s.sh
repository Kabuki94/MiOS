#!/bin/bash
# CloudWS v0.1.8 — 13-ceph-k3s: Ceph distributed storage + K3s Kubernetes
# Cephadm runs ALL server daemons as Podman containers.
# Only client tools + orchestrator binary are baked into the image.
#
# v2.1.1 FIXES:
#   - K3s manifests stored in /usr/share/cloudws/k3s-manifests/ (not /var)
#     First-boot service copies them to /var/lib/rancher/k3s/server/manifests/
#     This fixes bootc lint: /var content must use tmpfiles.d entries
#   - systemctl enables moved to Containerfile STEP D (unit files in system_files/)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ─── Ceph Client + Orchestrator ──────────────────────────────────────────────
echo "[13-ceph-k3s] Installing Ceph client tools and cephadm..."
install_packages "ceph"

# ─── K3s Prerequisites ───────────────────────────────────────────────────────
echo "[13-ceph-k3s] Installing K3s prerequisites..."
install_packages "k3s"

# Note: k3s-selinux policy is compiled from source in 19-k3s-selinux.sh

# ─── K3s Binary & Install Script ─────────────────────────────────────────────
echo "[13-ceph-k3s] Resolving latest K3s release tag..."
K3S_TAG=$(curl -sL -o /dev/null -w "%{url_effective}" https://github.com/k3s-io/k3s/releases/latest | grep -oE '[^/]+$' || true)

if [[ -z "$K3S_TAG" || "$K3S_TAG" == "latest" ]]; then
    echo "[13-ceph-k3s] FATAL: Could not resolve latest K3s tag."
    exit 1
fi
echo "[13-ceph-k3s] Latest K3s tag: $K3S_TAG"

echo "[13-ceph-k3s] Downloading K3s binary, checksum, and install script..."
K3S_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_TAG}/k3s"
K3S_SUM_URL="https://github.com/k3s-io/k3s/releases/download/${K3S_TAG}/sha256sum-amd64.txt"
K3S_INSTALL_URL="https://raw.githubusercontent.com/k3s-io/k3s/${K3S_TAG}/install.sh"

mkdir -p /tmp/k3s-dl
if curl -sfL "$K3S_URL" -o /tmp/k3s-dl/k3s 2>/dev/null && \
   curl -sfL "$K3S_SUM_URL" -o /tmp/k3s-dl/sha256sum.txt 2>/dev/null && \
   curl -sfL "$K3S_INSTALL_URL" -o /tmp/k3s-dl/k3s-install.sh 2>/dev/null; then
    cd /tmp/k3s-dl
    if grep -E "  k3s$" sha256sum.txt | sha256sum -c - >/dev/null 2>&1; then
        echo "[13-ceph-k3s] ✓ K3s SHA256 checksum verified"
        mv k3s /usr/local/bin/k3s
        chmod 755 /usr/local/bin/k3s

        # Only symlink if official RPM binaries don't exist, preventing PATH shadowing
        [ ! -f /usr/bin/kubectl ] && ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
        [ ! -f /usr/bin/crictl ] && ln -sf /usr/local/bin/k3s /usr/local/bin/crictl 2>/dev/null || true
        [ ! -f /usr/bin/ctr ] && ln -sf /usr/local/bin/k3s /usr/local/bin/ctr 2>/dev/null || true

        mv k3s-install.sh /usr/local/bin/k3s-install.sh
        chmod 755 /usr/local/bin/k3s-install.sh

        echo "[13-ceph-k3s] K3s binary and install script installed (tag: $K3S_TAG)"
    else
        echo "[13-ceph-k3s] FATAL: K3s binary SHA256 checksum mismatch! Aborting."
        exit 1
    fi
    cd - >/dev/null
else
    echo "[13-ceph-k3s] WARN: K3s download failed (non-fatal). Skipping K3s installation."
fi
rm -rf /tmp/k3s-dl

# ─── Pre-create directories in /etc (persists across updates) ────────────────
# NOTE: /var/lib/rancher is created by tmpfiles.d/cloudws-k3s.conf at boot.
# Manifests live in /usr/share/cloudws/k3s-manifests/ and get copied on first boot.
mkdir -p /etc/ceph /etc/rancher/k3s

# ─── Make bootstrap script executable ────────────────────────────────────────
chmod 755 /usr/local/bin/ceph-bootstrap.sh 2>/dev/null || true

# ─── NOTE: Service enables are in Containerfile STEP D ───────────────────────
# k3s.service, cloudws-ceph-bootstrap.service, var-home.mount,
# var-lib-containers.mount all live in system_files/ and are enabled
# AFTER the COPY step in the Containerfile.

echo "[13-ceph-k3s] Ceph + K3s stack installed."
echo "[13-ceph-k3s]   Ceph Dashboard:  https://<host>:8443 (after bootstrap)"
echo "[13-ceph-k3s]   K3s API server:  https://<host>:6443 (after boot)"
