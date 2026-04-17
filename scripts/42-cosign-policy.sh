#!/usr/bin/bash
# 42-cosign-policy.sh - verify cosign + trust policy landed
# cosign is now in PACKAGES.md packages-containers section (v2.2 addition).
set -euo pipefail

log() { printf '[42-cosign] %s\n' "$*"; }

if command -v cosign >/dev/null 2>&1; then
    log "OK: cosign installed ($(cosign version --json 2>/dev/null | head -1))"
else
    log "WARN: cosign not found - check packages-containers section of PACKAGES.md"
fi

for f in \
    /etc/containers/policy.json \
    /etc/containers/registries.d/ghcr.io.yaml \
    /etc/pki/containers/ublue-cosign.pub \
    /etc/pki/containers/cloudws-cosign.pub
do
    if [[ -f "$f" ]]; then
        log "OK: $f"
    else
        log "WARN: missing $f"
    fi
done