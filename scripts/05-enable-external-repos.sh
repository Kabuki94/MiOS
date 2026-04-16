#!/usr/bin/bash
# 50-install-repos.sh - enable every external repo unified packages depend on.
# Runs ONCE, before 51-install-unified-packages.sh.
set -euo pipefail

log() { printf '[50-repos] %s\n' "$*"; }

FEDORA_VER="$(rpm -E %fedora 2>/dev/null || echo 41)"
log "Fedora version detected: $FEDORA_VER"

# --- RPM Fusion free + nonfree ---------------------------------------------
log "enabling RPM Fusion"
dnf5 -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
    || log "WARN: RPM Fusion enable failed (may already be present from ucore-hci)"

# --- COPRs ------------------------------------------------------------------
log "enabling ublue-os/packages (for uupd; already enabled in 43 but idempotent)"
dnf5 -y copr enable ublue-os/packages || true

log "enabling hikariknight/looking-glass-kvmfr (for akmod-kvmfr)"
dnf5 -y copr enable hikariknight/looking-glass-kvmfr || true

log "enabling @bazzite-org/bazzite (for patched gamescope + steam-devices udev)"
dnf5 -y copr enable bazzite-org/bazzite || true

log "enabling @bazzite-org/bazzite-multilib (for 32-bit Steam deps)"
dnf5 -y copr enable bazzite-org/bazzite-multilib || true

# --- CrowdSec packagecloud --------------------------------------------------
log "enabling CrowdSec packagecloud repo"
curl -fsSL https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | bash || \
    log "WARN: CrowdSec repo setup failed"

# --- K3s: official rpm repo via rancher -------------------------------------
log "installing K3s selinux context (k3s binary installed via script at runtime)"
# K3s itself is a single binary; install the SELinux policy RPM now so the
# binary works at runtime without policy violations.
dnf5 -y install https://rpm.rancher.io/k3s/stable/common/coreos/noarch/k3s-selinux-1.6-1.coreos.noarch.rpm || \
    log "WARN: k3s-selinux install failed; will need alternative path"

# --- Waydroid needs LXC from Fedora + their repo for waydroid itself --------
# Waydroid is in Fedora proper as of F38+, so no extra repo needed.
# Just making sure fedora/fedora-updates are accessible.

log "all external repos enabled"