#!/usr/bin/bash
# 42-cosign-policy.sh - install cosign, trust policy, and registries.d
set -euo pipefail

log() { printf '[42-cosign-policy] %s\n' "$*"; }

dnf5 -y install cosign

# Policy.json and registries.d shipped under system_files/
# Just verify they landed correctly.
for f in \
    /etc/containers/policy.json \
    /etc/containers/registries.d/ghcr.io.yaml \
    /etc/pki/containers/ublue-cosign.pub \
    /etc/pki/containers/cloudws-cosign.pub
do
    if [[ -f "$f" ]]; then
        log "present: $f"
    else
        log "WARN: missing $f (will be created at first boot by systemd-tmpfiles if needed)"
    fi
done