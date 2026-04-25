# 30-network.sh
---

#!/bin/bash
# 🌐 MiOS — Universal AI Integration
# Greenboot health check: Network reachability

set -e

echo "Starting network health check..."

# Wait up to 30s for DNS resolution of ghcr.io (our primary registry)
TIMEOUT=30
INTERVAL=2
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    if getent hosts ghcr.io > /dev/null; then
        echo "Network check passed: ghcr.io resolved."
        exit 0
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    echo "Waiting for network... ($ELAPSED/$TIMEOUT)"
done

echo "Network check failed: ghcr.io did not resolve within $TIMEOUT seconds."
exit 1
