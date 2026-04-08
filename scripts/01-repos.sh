#!/bin/bash
# CloudWS v2.0 — 01-repos: Fedora 44 + Rawhide kernel overlay on ucore
#
# STRATEGY: ucore-hci:stable-nvidia is Fedora CoreOS-based (fc43 stable).
# We add Fedora 44 repos and distro-sync for GNOME 50, Mesa 26, systemd 260,
# stable SELinux policy, etc. Kernel comes from Rawhide (Linux 7.0 RC).
#
# WHY SPLIT: Rawhide (fc45) has missing SELinux types and duplicate shim
# binaries. Fedora 44 has stable policy. But F44 ships kernel 6.19 —
# we want 7.0 RC, so kernel packages come from Rawhide via includepkgs.
#
# install_weakdeps=False is set BEFORE any installs. Both docs say this is
# "non-negotiable for minimalism" — prevents hundreds of Recommends packages.
#
# Priority hierarchy (Bazzite pattern):
#   CrowdSec(80) < Terra(85) < RPMFusion(90) < Fedora 44(95) < ucore base(99)
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

# ── Fedora 44 repo overlay ─────────────────────────────────────────────────
# Fedora 44: GNOME 50, Linux 6.19, Mesa 26, systemd 260
# GA target: April 14, 2026. Beta available since March 10, 2026.
echo "[01-repos] Adding Fedora 44 repository..."
cat > /etc/yum.repos.d/fedora-44.repo <<'EOREPO'
[fedora-44]
name=Fedora 44 - $basearch
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-44&arch=$basearch
enabled=1
countme=1
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-44-$basearch
skip_if_unavailable=False
priority=95

[fedora-44-updates]
name=Fedora 44 Updates - $basearch
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f44&arch=$basearch
enabled=1
countme=1
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-44-$basearch
skip_if_unavailable=True
priority=95
EOREPO

# ── Distro-sync to Fedora 44 ───────────────────────────────────────────────
# Upgrades ucore's fc43 packages to Fedora 44 versions.
# --allowerasing handles package renames/splits between Fedora versions.
# Exclude shim/grub: ucore ships pre-signed EFI binaries with ublue's MOK key.
# Exclude kernel*: we pull the latest RC kernel from Rawhide separately.
echo "[01-repos] Distro-sync to Fedora 44 (this takes a while)..."
dnf distro-sync -y --best --allowerasing \
    --exclude='shim-*' \
    --exclude='grub2-efi-*' \
    --exclude='kernel*' \
    --setopt=install_weak_deps=False 2>&1 | tail -30 || {
    echo "[01-repos] WARNING: distro-sync had errors — check output above"
}

# ── Rawhide kernel (Linux 7.0 RC) ──────────────────────────────────────────
# F44 ships 6.19. Rawhide has 7.0 RCs. Pull kernel ONLY from Rawhide.
echo "[01-repos] Adding Rawhide repo (kernel only)..."
cat > /etc/yum.repos.d/fedora-rawhide-kernel.repo <<'EOREPO'
[fedora-rawhide-kernel]
name=Fedora Rawhide - Kernel Only
metalink=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch
enabled=1
metadata_expire=6h
repo_gpgcheck=0
type=rpm
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-rawhide-$basearch
includepkgs=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra,kernel-devel,kernel-headers,linux-firmware
skip_if_unavailable=True
priority=90
EOREPO

echo "[01-repos] Upgrading kernel to latest Rawhide (7.0 RC)..."
dnf upgrade -y --best kernel kernel-core kernel-modules kernel-modules-core \
    kernel-modules-extra linux-firmware \
    --repo=fedora-rawhide-kernel \
    --setopt=install_weak_deps=False 2>&1 | tail -20 || {
    echo "[01-repos] WARNING: Rawhide kernel upgrade had errors"
}

# ── RPMFusion Free + Nonfree (Fedora 44) ────────────────────────────────────
echo "[01-repos] Installing RPMFusion Free + Nonfree for Fedora 44..."
dnf install -y --setopt=install_weak_deps=False \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

dnf config-manager setopt rpmfusion-free.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-free-updates.priority=90 2>/dev/null || true
dnf config-manager setopt rpmfusion-nonfree-updates.priority=90 2>/dev/null || true

# ── Terra repo (Fyra Labs) — gamescope-session-steam ────────────────────────
echo "[01-repos] Installing Terra repo..."
dnf install -y --setopt=install_weak_deps=False --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra44' \
    terra-release 2>/dev/null || true
dnf config-manager setopt terra.priority=85 2>/dev/null || true

# ── CrowdSec (Fedora 40 fallback — compat with 44) ──────────────────────────
echo "[01-repos] Adding CrowdSec repo..."
cat > /etc/yum.repos.d/crowdsec.repo <<'EOREPO'
[crowdsec]
name=CrowdSec
baseurl=https://packagecloud.io/crowdsec/crowdsec/fedora/40/$basearch
gpgcheck=0
enabled=1
priority=80
EOREPO

echo "[01-repos] Done. ucore (fc43) + F44 userspace + Rawhide kernel (7.0 RC) + RPMFusion + Terra + CrowdSec."
echo "[01-repos] Priority: CrowdSec(80) < Terra(85) < RPMFusion(90) < Rawhide-kernel(90) < F44(95) < ucore(99)"
