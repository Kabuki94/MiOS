#!/bin/bash
# CloudWS v2.1.1 — 13-ceph-k3s: Ceph distributed storage + K3s Kubernetes
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

# ─── K3s Binary ──────────────────────────────────────────────────────────────
echo "[13-ceph-k3s] Downloading K3s binary..."
curl -sfL "https://github.com/k3s-io/k3s/releases/latest/download/k3s" -o /usr/local/bin/k3s 2>/dev/null || true
if [ -f /usr/local/bin/k3s ]; then
    chmod 755 /usr/local/bin/k3s
    ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
    ln -sf /usr/local/bin/k3s /usr/local/bin/crictl 2>/dev/null || true
    ln -sf /usr/local/bin/k3s /usr/local/bin/ctr 2>/dev/null || true
    echo "[13-ceph-k3s] K3s binary installed"
else
    echo "[13-ceph-k3s] WARN: K3s download failed (non-fatal)"
fi
curl -sfL https://get.k3s.io -o /usr/local/bin/k3s-install.sh 2>/dev/null || true
chmod +x /usr/local/bin/k3s-install.sh 2>/dev/null || true

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
