#!/bin/bash
# CloudWS — 01-repos: Repository initialization
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# RPMFusion (Free + Nonfree) for NVIDIA drivers and multimedia codecs
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-rawhide.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-rawhide.noarch.rpm

# Terra repo (Fyra Labs) — provides gamescope-session-steam for SteamOS GDM session
dnf install -y --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release 2>/dev/null || true

echo "[01-repos] Fedora Rawhide + RPMFusion Free/Nonfree + Terra initialized."
