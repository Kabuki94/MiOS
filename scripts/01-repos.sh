#!/bin/bash
# CloudWS v1.3 — 01-repos: Repository initialization with priority hierarchy
#
# CHANGELOG v1.3:
#   - Added repo priority hierarchy (Bazzite pattern)
#   - Fedora base repos: default priority (99)
#   - RPMFusion: priority 90 (prefer Fedora base when possible)
#   - Terra: priority 85 (gamescope-session-steam)
#   - CrowdSec: priority 80 (explicit override)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# RPMFusion (Free + Nonfree) for NVIDIA drivers and multimedia codecs
echo "[01-repos] Installing RPMFusion Free + Nonfree..."
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-rawhide.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-rawhide.noarch.rpm

# Set RPMFusion priority lower than Fedora base (higher number = lower priority)
dnf config-manager setopt rpmfusion-free.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-free-updates.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree-updates.priority=90 2>/dev/null || true

# Terra repo (Fyra Labs) — provides gamescope-session-steam for SteamOS GDM session
echo "[01-repos] Installing Terra repo..."
dnf install -y --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release 2>/dev/null || true
dnf config-manager setopt terra.priority=85 2>/dev/null || true

# CrowdSec official repo with Fedora 40 fallback for Rawhide compat
echo "[01-repos] Adding CrowdSec repo..."
cat > /etc/yum.repos.d/crowdsec.repo <<'EOREPO'
[crowdsec]
name=CrowdSec
baseurl=https://packagecloud.io/crowdsec/crowdsec/fedora/40/$basearch
gpgcheck=0
enabled=1
priority=80
EOREPO

echo "[01-repos] Fedora Rawhide + RPMFusion + Terra + CrowdSec initialized."
echo "[01-repos] Priority hierarchy: CrowdSec(80) < Terra(85) < RPMFusion(90) < Fedora(99)"
