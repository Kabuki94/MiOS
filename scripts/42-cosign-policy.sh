#!/usr/bin/env bash
# ============================================================================
# scripts/42-cosign-policy.sh - CloudWS-bootc v0.1.8
# ----------------------------------------------------------------------------
# Consolidates cosign binary installation, Sigstore trust roots, and policy.json.
# Supercedes 37-cosign-policy.sh.
#
# Note: we pin to v2.6.3 because v3 breaks rpm-ostree bundle format (OCI 1.1).
# ============================================================================
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

log "42-cosign-policy: ensuring cosign + trust roots + policy.json"

# 1. Install cosign binary (pinned to v2.x for rpm-ostree compatibility)
if ! command -v cosign >/dev/null 2>&1; then
    log "  downloading cosign v2.6.3 static binary..."
    curl -sL "https://github.com/sigstore/cosign/releases/download/v2.6.3/cosign-linux-amd64" -o /usr/local/bin/cosign
    chmod +x /usr/local/bin/cosign
fi

SYSFILES="/ctx/system_files"
install -d -m 0755 /etc/pki/containers
install -d -m 0755 /etc/containers/registries.d

# 2. Install policy.json
if [[ -f "${SYSFILES}/etc/containers/policy.json" ]]; then
    install -m 0644 "${SYSFILES}/etc/containers/policy.json" /etc/containers/policy.json
    log "  installed /etc/containers/policy.json"
else
    # Fallback to in-image path if ctx is missing (unlikely in build)
    [[ -f /etc/containers/policy.json ]] || warn "missing policy.json"
fi

# 3. Install Sigstore TUF roots and public keys
# These ship via the system_files/etc/pki/containers/ overlay
for f in fulcio_v1.crt.pem rekor.pub ublue-os.pub ublue-cosign.pub cloudws-cosign.pub; do
    src="${SYSFILES}/etc/pki/containers/${f}"
    dst="/etc/pki/containers/${f}"
    if [[ -f "${src}" ]]; then
        install -m 0644 "${src}" "${dst}"
        log "  installed ${dst}"
    fi
done

# 4. JSON Sanity Check
if command -v jq >/dev/null 2>&1 && [[ -f /etc/containers/policy.json ]]; then
    jq -e . /etc/containers/policy.json >/dev/null || die "policy.json failed jq parse"
    log "  policy.json parses cleanly"
fi

log "42-cosign-policy: validation complete"
