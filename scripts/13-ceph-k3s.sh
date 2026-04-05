#!/bin/bash
# CloudWS — 13-ceph-k3s: Ceph distributed storage + K3s Kubernetes
# Cephadm runs ALL server daemons as Podman containers.
# Only client tools + orchestrator binary are baked into the image.
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

# ─── Pre-create directories ─────────────────────────────────────────────────
mkdir -p /etc/ceph /etc/rancher/k3s \
         /var/lib/ceph /var/log/ceph \
         /var/lib/rancher/k3s/server/manifests

# ─── Make bootstrap script executable ────────────────────────────────────────
chmod 755 /usr/local/bin/ceph-bootstrap.sh 2>/dev/null || true

# ─── Enable services ─────────────────────────────────────────────────────────
systemctl enable k3s.service 2>/dev/null || true
systemctl enable ceph-bootstrap.service 2>/dev/null || true
systemctl enable var-home.mount 2>/dev/null || true
systemctl enable var-lib-containers.mount 2>/dev/null || true

echo "[13-ceph-k3s] Ceph + K3s stack installed."
echo "[13-ceph-k3s]   Ceph Dashboard:  https://<host>:8443 (after bootstrap)"
echo "[13-ceph-k3s]   K3s API server:  https://<host>:6443 (after boot)"
