#!/bin/bash
# CloudWS v2.0 — 01-repos: Rawhide overlay on ucore + repo hierarchy
#
# STRATEGY: ucore-hci:stable-nvidia is Fedora CoreOS-based (stable release).
# We add Fedora Rawhide repos and distro-sync to pull GNOME 50, latest Mesa,
# systemd, etc. This is safe in a Containerfile — it's just filesystem-level
# RPM transactions. The ostree/bootc deployment happens at install time.
#
# install_weakdeps=False is set BEFORE any installs. Both docs say this is
# "non-negotiable for minimalism" — prevents hundreds of Recommends packages.
#
# Priority hierarchy (Bazzite pattern):
#   CrowdSec(80) < Terra(85) < RPMFusion(90) < Rawhide(95) < ucore base(99)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ── Global DNF config ───────────────────────────────────────────────────────
# CRITICAL: Set BEFORE any dnf operations.
echo "[01-repos] Setting install_weakdeps=False globally..."
if ! grep -q "^install_weakdeps=" /etc/dnf/dnf.conf 2>/dev/null; then
    echo "install_weakdeps=False" >> /etc/dnf/dnf.conf
else
    sed -i 's/^install_weakdeps=.*/install_weakdeps=False/' /etc/dnf/dnf.conf
fi

# ── Fedora Rawhide repo overlay ─────────────────────────────────────────────
echo "[01-repos] Adding Fedora Rawhide repository..."
cat > /etc/yum.repos.d/fedora-rawhide.repo <<'EOREPO'
[fedora-rawhide]
name=Fedora - Rawhide - Developmental packages for the next Fedora release
metalink=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch
enabled=1
countme=1
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-rawhide-$basearch
skip_if_unavailable=False
priority=95
EOREPO

# ── Distro-sync to Rawhide ──────────────────────────────────────────────────
# Upgrades ucore's Fedora stable packages to Rawhide versions.
# --allowerasing handles package renames/splits between Fedora versions.
echo "[01-repos] Distro-sync to Rawhide (this takes a while)..."
dnf distro-sync -y --best --allowerasing \
    --setopt=install_weak_deps=False 2>&1 | tail -30 || {
    echo "[01-repos] WARNING: distro-sync had errors — check output above"
}

# ── RPMFusion Free + Nonfree ────────────────────────────────────────────────
echo "[01-repos] Installing RPMFusion Free + Nonfree..."
dnf install -y --setopt=install_weak_deps=False \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-rawhide.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-rawhide.noarch.rpm

dnf config-manager setopt rpmfusion-free.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-free-updates.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree-updates.priority=90 2>/dev/null || true

# ── Terra repo (Fyra Labs) — gamescope-session-steam ────────────────────────
echo "[01-repos] Installing Terra repo..."
dnf install -y --setopt=install_weak_deps=False --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release 2>/dev/null || true
dnf config-manager setopt terra.priority=85 2>/dev/null || true

# ── CrowdSec (Fedora 40 fallback for Rawhide compat) ────────────────────────
echo "[01-repos] Adding CrowdSec repo..."
cat > /etc/yum.repos.d/crowdsec.repo <<'EOREPO'
[crowdsec]
name=CrowdSec
baseurl=https://packagecloud.io/crowdsec/crowdsec/fedora/40/$basearch
gpgcheck=0
enabled=1
priority=80
EOREPO

echo "[01-repos] Done. ucore base + Rawhide overlay + RPMFusion + Terra + CrowdSec."
echo "[01-repos] Priority: CrowdSec(80) < Terra(85) < RPMFusion(90) < Rawhide(95) < ucore(99)"
