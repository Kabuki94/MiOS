#!/usr/bin/bash
# 05-enable-external-repos.sh - enable every external repo unified packages
# depend on. Runs ONCE, after 01-repos.sh and 02-kernel.sh.
#
# v2.2.8 fix:
#   - Strip sslcacert= line from CrowdSec's packagecloud .repo file. The
#     packagecloud install script writes sslcacert=/etc/pki/tls/certs/ca-bundle.crt
#     which curl inside the buildroot can't open, producing Curl (77) on every
#     subsequent dnf refresh. Removing the line makes curl fall back to the
#     system default trust store, which works fine.
set -euo pipefail

log() { printf '[50-repos] %s\n' "$*"; }

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || echo 41)"
log "Fedora version detected: $FEDORA_VER"

# RPM Fusion is already enabled in 01-repos.sh with explicit F44 priority.

# --- COPRs ------------------------------------------------------------------
log "enabling ublue-os/packages (for uupd; already enabled in 43 but idempotent)"
dnf -y copr enable ublue-os/packages || true

log "enabling hikariknight/looking-glass-kvmfr (for akmod-kvmfr)"
dnf -y copr enable hikariknight/looking-glass-kvmfr || true

log "enabling @bazzite-org/bazzite (for patched gamescope + steam-devices udev)"
dnf -y copr enable bazzite-org/bazzite || true

log "enabling @bazzite-org/bazzite-multilib (for 32-bit Steam deps)"
dnf -y copr enable bazzite-org/bazzite-multilib || true

# --- CrowdSec packagecloud --------------------------------------------------
log "enabling CrowdSec packagecloud repo"
curl -fsSL https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | bash || \
    log "WARN: CrowdSec repo setup failed"

# Neutralize sslcacert= lines that point at paths curl can't open inside the
# buildroot. Applies to every .repo file dropped by the packagecloud script.
# This prevents the "Curl error (77): Problem with the SSL CA cert" spam
# that otherwise appears on every dnf refresh for the rest of the build.
for repo in /etc/yum.repos.d/crowdsec_crowdsec*.repo; do
    if [[ -f "$repo" ]]; then
        sed -i '/^sslcacert=/d' "$repo"
        log "stripped sslcacert= from $(basename "$repo")"
    fi
done

# --- K3s: official rpm repo via rancher -------------------------------------
log "installing K3s selinux context (k3s binary installed via script at runtime)"
# K3s itself is a single binary; install the SELinux policy RPM now so the
# binary works at runtime without policy violations.
dnf -y install https://rpm.rancher.io/k3s/stable/common/coreos/noarch/k3s-selinux-1.6-1.coreos.noarch.rpm || \
    log "WARN: k3s-selinux install failed; will need alternative path"

# --- Waydroid needs LXC from Fedora + their repo for waydroid itself --------
# Waydroid is in Fedora proper as of F38+, so no extra repo needed.
# Just making sure fedora/fedora-updates are accessible.

log "all external repos enabled"
