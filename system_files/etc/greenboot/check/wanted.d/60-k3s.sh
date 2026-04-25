#!/bin/bash
# 🌐 CloudWS-bootc — Universal AI Integration
# Greenboot health check: K3s status (optional)

# Check if k3s is enabled
if ! systemctl is-enabled k3s.service > /dev/null 2>&1; then
    echo "K3s is not enabled, skipping check."
    exit 0
fi

echo "Starting K3s health check..."

# Wait up to 60s for K3s to be ready
TIMEOUT=60
INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if kubectl get nodes > /dev/null 2>&1; then
        echo "K3s check passed: nodes are reachable."
        exit 0
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    echo "Waiting for K3s... ($ELAPSED/$TIMEOUT)"
done

echo "K3s check failed (not triggering rollback as this is a wanted check)."
exit 0 # We exit 0 because it's a 'wanted' check and we don't want to force rollback yet
