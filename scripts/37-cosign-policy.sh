#!/usr/bin/env bash
# ============================================================================
# scripts/37-cosign-policy.sh - CloudWS-bootc v2.1.6
# ----------------------------------------------------------------------------
# Install cosign keyless-verification policy + Sigstore TUF trust roots
# into the final image. Runs after 36-akmod-guards.sh.
#
# Prereq: the Containerfile must COPY system_files/ into /ctx before this
# script runs. Required files under system_files/:
#   etc/containers/policy.json
#   etc/containers/registries.d/ghcr.io-kabuki94.yaml
#   sigstore/fulcio_v1.crt.pem   (from sigstore/root-signing TUF repo)
#   sigstore/rekor.pub           (from sigstore/root-signing TUF repo)
#   sigstore/ublue-os.pub        (from ublue-os/main cosign.pub)
#
# If any of the sigstore key/cert files are missing (e.g. during an early
# v2.1.6 bootstrap where they haven't been committed yet), this script
# falls back gracefully: the policy.json still installs but inbound image
# pulls matching its strict rules will fail until the roots are populated.
# That is the correct safety posture for keyless verification.
# ============================================================================
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

log "37-cosign-policy: installing Sigstore trust roots + policy.json"

SYSFILES="/ctx/system_files"

install -d -m 0755 /etc/pki/containers
install -d -m 0755 /etc/containers/registries.d

# --- policy.json (always required) ------------------------------------------
if [[ -f "${SYSFILES}/etc/containers/policy.json" ]]; then
    install -m 0644 "${SYSFILES}/etc/containers/policy.json" \
        /etc/containers/policy.json
    log "  installed /etc/containers/policy.json"
else
    die "missing ${SYSFILES}/etc/containers/policy.json"
fi

# --- registries.d dropin ----------------------------------------------------
if [[ -f "${SYSFILES}/etc/containers/registries.d/ghcr.io-kabuki94.yaml" ]]; then
    install -m 0644 \
        "${SYSFILES}/etc/containers/registries.d/ghcr.io-kabuki94.yaml" \
        /etc/containers/registries.d/ghcr.io-kabuki94.yaml
    log "  installed /etc/containers/registries.d/ghcr.io-kabuki94.yaml"
else
    warn "missing registries.d/ghcr.io-kabuki94.yaml — sigstore attachments will not be consulted"
fi

# --- Sigstore TUF roots (best-effort) ---------------------------------------
for f in fulcio_v1.crt.pem rekor.pub ublue-os.pub; do
    src="${SYSFILES}/sigstore/${f}"
    dst="/etc/pki/containers/${f}"
    if [[ -f "${src}" ]]; then
        install -m 0644 "${src}" "${dst}"
        log "  installed ${dst}"
    else
        warn "missing ${src} — install manually before enabling strict verify"
    fi
done

# --- SELinux relabel --------------------------------------------------------
if command -v restorecon >/dev/null 2>&1; then
    restorecon -RF /etc/pki/containers \
                   /etc/containers/policy.json \
                   /etc/containers/registries.d 2>/dev/null || true
fi

# --- JSON sanity check ------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    jq -e . /etc/containers/policy.json >/dev/null \
        || die "policy.json failed jq parse"
    log "  policy.json parses cleanly"
fi

log "37-cosign-policy: done"
