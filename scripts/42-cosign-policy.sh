#!/usr/bin/bash
# 42-cosign-policy.sh - verify cosign + trust policy landed
# cosign is now in PACKAGES.md packages-containers section (v2.2 addition).
set -euo pipefail

log() { printf '[42-cosign] %s\n' "$*"; }

command -v cosign >/dev/null 2>&1 && log "OK: cosign installed ($(cosign version --json 2>/dev/null | head -1))" \
    || log "WARN: cosign not found - check packages-containers section of PACKAGES.md"

for f in \
    /etc/containers/policy.json \
    /etc/containers/registries.d/ghcr.io.yaml \
    /etc/pki/containers/ublue-cosign.pub \
    /etc/pki/containers/cloudws-cosign.pub
do
    [[ -f "$f" ]] && log "OK: $f" || log "WARN: missing $f"
done