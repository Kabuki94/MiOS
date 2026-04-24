#!/bin/bash
# CloudWS greenboot advisory check: K3s readiness
# In wanted.d — failure emits a warning but does NOT trigger rollback.
# K3s is only active on server/hybrid roles; desktop roles skip this gracefully.
set -euo pipefail

if ! systemctl is-enabled k3s.service >/dev/null 2>&1; then
    echo "[greenboot/60-k3s] K3s not enabled on this role — skipping"
    exit 0
fi

echo "[greenboot/60-k3s] Waiting for K3s to become active..."
TIMEOUT=60
ELAPSED=0
while ! systemctl is-active --quiet k3s.service; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
        echo "[greenboot/60-k3s] WARN — K3s not active after ${TIMEOUT}s"
        exit 1
    fi
done

echo "[greenboot/60-k3s] K3s active — checking node readiness..."
if ! kubectl get nodes 2>/dev/null | grep -q "Ready"; then
    echo "[greenboot/60-k3s] WARN — no Ready nodes found"
    exit 1
fi

echo "[greenboot/60-k3s] OK — K3s ready"
exit 0
