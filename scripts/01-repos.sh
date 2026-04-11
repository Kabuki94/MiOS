#!/bin/bash
# CloudWS v0.1.1 — 01-repos: Fedora 44 overlay on ucore (base kernel preserved)
#
# STRATEGY: ucore-hci:stable-nvidia is Fedora CoreOS-based (fc43 stable).
# We add Fedora 44 repos and distro-sync for GNOME 50, Mesa 26, systemd 260,
# stable SELinux policy, etc. Kernel stays at the base image version.
#
# WHY BASE KERNEL: ucore ships pre-signed NVIDIA modules that match its kernel.
# Upgrading to rawhide kernel breaks dkms (kernel-devel-matched mismatch),
# invalidates NVIDIA kmod signatures, and gains little for a workstation.
# Rawhide kernel (7.0 RC) is available as an opt-in post-install command.
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
echo "[01-repos] Setting install_weak_deps=False globally..."
# dnf5 option is install_weak_deps (with underscore), NOT install_weakdeps (dnf4)
# Wrong name is silently ignored → hundreds of Recommends packages leak in
sed -i '/^install_weakdeps=/d' /etc/dnf/dnf.conf 2>/dev/null || true
sed -i '/^install_weak_deps=/d' /etc/dnf/dnf.conf 2>/dev/null || true
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

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
# Exclude shim: ucore ships pre-signed EFI binaries with ublue's MOK key.
# Exclude kernel*: preserve the base image kernel + pre-signed NVIDIA modules.
echo "[01-repos] Distro-sync to Fedora 44 (this takes a while)..."
dnf distro-sync -y --best --allowerasing \
    --exclude='shim-*' \
    --exclude='kernel*' \
    --setopt=install_weak_deps=False 2>&1 | tail -30 || {
    echo "[01-repos] WARNING: distro-sync had errors — check output above"
}

# ── Pre-install F44 ca-certificates ────────────────────────────────────────
# Steam's %post scriptlet calls `update-ca-trust extract --rhbz2387674`
# which only exists in F44's ca-certificates. Without this, the entire 500+
# package gaming transaction rolls back, losing systemd/glibc/libsepol upgrades.
echo "[01-repos] Ensuring F44 ca-certificates is installed..."
dnf install -y ca-certificates p11-kit-trust 2>&1 | tail -5 || true

# ── Rawhide kernel — DISABLED BY DEFAULT ────────────────────────────────────
# The base ucore kernel works with pre-signed NVIDIA modules and matching
# kernel-devel. Rawhide kernel (7.0 RC) breaks dkms and NVIDIA signatures.
#
# To opt-in to rawhide kernel at build time, set CLOUDWS_RAWHIDE_KERNEL=1:
#   podman build --build-arg CLOUDWS_RAWHIDE_KERNEL=1 ...
#
# To opt-in on a running system:
#   cloudws-kernel-rawhide   (post-install command, rebuilds NVIDIA kmod)
if [[ "${CLOUDWS_RAWHIDE_KERNEL:-0}" == "1" ]]; then
    echo "[01-repos] RAWHIDE KERNEL ENABLED — upgrading to Linux 7.0 RC..."
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
includepkgs=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra,kernel-devel,kernel-headers,linux-firmware,linux-firmware-whence
skip_if_unavailable=True
priority=90
EOREPO

    dnf distro-sync -y --best \
        kernel kernel-core kernel-modules kernel-modules-core \
        kernel-modules-extra kernel-devel kernel-headers \
        linux-firmware linux-firmware-whence \
        --setopt=install_weak_deps=False 2>&1 | tail -20 || {
        echo "[01-repos] WARNING: Rawhide kernel upgrade had errors"
    }
else
    echo "[01-repos] Using base image kernel (rawhide kernel disabled — set CLOUDWS_RAWHIDE_KERNEL=1 to enable)"
fi

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
# gpgcheck disabled: BIB re-enables repos during ISO builds and the
# terra44 GPG key path doesn't exist, causing ISO generation to fail.
echo "[01-repos] Installing Terra repo..."
dnf install -y --setopt=install_weak_deps=False --nogpgcheck \
    --repofrompath 'terra,https://repos.fyralabs.com/terra44' \
    terra-release 2>/dev/null || true
dnf config-manager setopt terra.priority=85 2>/dev/null || true
dnf config-manager setopt terra.gpgcheck=0 2>/dev/null || true
# BIB reads raw .repo files, not dnf config-manager overrides.
# Strip the gpgkey path that points to a nonexistent file.
sed -i '/^gpgkey.*terra/d' /etc/yum.repos.d/terra*.repo 2>/dev/null || true
sed -i 's/^gpgcheck=1/gpgcheck=0/' /etc/yum.repos.d/terra*.repo 2>/dev/null || true

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

echo "[01-repos] Done. ucore base kernel + F44 userspace + RPMFusion + Terra + CrowdSec."
echo "[01-repos] Priority: CrowdSec(80) < Terra(85) < RPMFusion(90) < F44(95) < ucore(99)"
