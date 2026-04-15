#!/bin/bash
# CloudWS v0.1.4 — 01-repos: Fedora 44 overlay on ucore (base kernel preserved)
#
# FIX v0.1.4: Two-phase distro-sync to handle filesystem scriptlet failure.
# The filesystem package's lua %posttrans fails in container builds, aborting
# the entire 1162-package transaction. Without this fix, the system boots with
# F43 core libs but F44 desktop packages — a broken ABI mismatch.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

# ── Global DNF config ───────────────────────────────────────────────────────
echo "[01-repos] Setting install_weak_deps=False globally..."
sed -i '/^install_weakdeps=/d' /etc/dnf/dnf.conf 2>/dev/null || true
sed -i '/^install_weak_deps=/d' /etc/dnf/dnf.conf 2>/dev/null || true
echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

# ── Fedora 44 repo overlay ─────────────────────────────────────────────────
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

# ── Distro-sync to Fedora 44 (TWO-PHASE) ───────────────────────────────────
echo "[01-repos] Distro-sync to Fedora 44 (this takes a while)..."

SYNC_OK=0

# Phase 1: Try normal distro-sync
echo "[01-repos] Phase 1: Clean distro-sync attempt..."
if dnf distro-sync -y --best --allowerasing \
    --exclude='shim-*' \
    --exclude='kernel*' \
    --setopt=install_weak_deps=False 2>&1 | tail -30; then
    SYNC_OK=1
    echo "[01-repos] ✓ Distro-sync completed cleanly"
fi

if [ "$SYNC_OK" -eq 0 ]; then
    echo "[01-repos] Phase 1 failed (expected — filesystem scriptlet issue)"
    echo "[01-repos] Phase 2: distro-sync with --skip-broken..."

    dnf distro-sync -y --best --allowerasing --skip-broken \
        --exclude='shim-*' \
        --exclude='kernel*' \
        --setopt=install_weak_deps=False 2>&1 | tail -30 || {
        echo "[01-repos] WARNING: Phase 2 also had issues — continuing with force approach"
    }

    # Phase 3: Force-install critical core packages individually
    echo "[01-repos] Phase 3: Force-installing critical core packages..."
    for pkg in systemd dbus-broker glib2 polkit glibc glibc-common \
               libselinux libsemanage selinux-policy selinux-policy-targeted \
               p11-kit p11-kit-trust ca-certificates openssl-libs nss nss-softokn \
               nss-util libsepol audit-libs; do
        dnf install -y --allowerasing --best "$pkg" 2>&1 | tail -3 || true
    done

    # Verify critical packages upgraded
    echo "[01-repos] Verifying core package versions..."
    SYSTEMD_VER=$(rpm -q systemd 2>/dev/null || echo "MISSING")
    GLIBC_VER=$(rpm -q glibc 2>/dev/null || echo "MISSING")
    DBUS_VER=$(rpm -q dbus-broker 2>/dev/null || echo "MISSING")
    echo "[01-repos]   systemd:     $SYSTEMD_VER"
    echo "[01-repos]   glibc:       $GLIBC_VER"
    echo "[01-repos]   dbus-broker: $DBUS_VER"

    if rpm -q systemd | grep -q 'fc43'; then
        echo "[01-repos] CRITICAL WARNING: systemd is still at FC43 version!"
        echo "[01-repos] Attempting aggressive upgrade..."
        dnf upgrade -y --allowerasing systemd 'systemd-*' 2>&1 | tail -10 || true
    fi
fi

# ── Pre-install F44 ca-certificates ────────────────────────────────────────
echo "[01-repos] Ensuring F44 ca-certificates is installed..."
dnf install -y ca-certificates p11-kit-trust 2>&1 | tail -5 || true

# ── Rawhide kernel — DISABLED BY DEFAULT ────────────────────────────────────
if [ "${CLOUDWS_RAWHIDE_KERNEL:-0}" = "1" ]; then
    echo "[01-repos] RAWHIDE KERNEL: Installing Fedora Rawhide kernel repo..."
    cat > /etc/yum.repos.d/fedora-rawhide-kernel.repo <<'EOREPO'
[fedora-rawhide-kernel]
name=Fedora Rawhide - Kernel Only - $basearch
metalink=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch
enabled=1
repo_gpgcheck=0
type=rpm
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-rawhide-$basearch
skip_if_unavailable=True
includepkgs=kernel,kernel-core,kernel-modules,kernel-modules-core,kernel-modules-extra,kernel-devel,kernel-devel-matched,kernel-headers
priority=50
EOREPO
    echo "[01-repos] RAWHIDE KERNEL: Installing latest rawhide kernel..."
    dnf install -y kernel kernel-core kernel-modules kernel-modules-core \
        kernel-modules-extra kernel-devel kernel-devel-matched 2>&1 | tail -15 || {
        echo "[01-repos] WARNING: Rawhide kernel install failed — using base image kernel"
    }
else
    echo "[01-repos] Using base image kernel (rawhide kernel disabled — set CLOUDWS_RAWHIDE_KERNEL=1 to enable)"
fi

# ── RPMFusion ───────────────────────────────────────────────────────────────
echo "[01-repos] Installing RPMFusion Free + Nonfree for Fedora 44..."
dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm" \
    2>&1 | tail -15 || true

for repo in rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates; do
    if [ -f "/etc/yum.repos.d/${repo}.repo" ]; then
        if ! grep -q '^priority=' "/etc/yum.repos.d/${repo}.repo"; then
            sed -i '/^\['"$repo"'\]/a priority=90' "/etc/yum.repos.d/${repo}.repo"
        fi
    fi
done

# ── Terra repo ──────────────────────────────────────────────────────────────
echo "[01-repos] Installing Terra repo..."
dnf install -y --repofrompath 'terra,https://repos.fyralabs.com/terra44' \
    --setopt='terra.gpgcheck=1' --setopt='terra.gpgkey=https://repos.fyralabs.com/terra44/key.asc' \
    terra-release 2>&1 | tail -10 || true

if [ -f /etc/yum.repos.d/terra.repo ]; then
    if ! grep -q '^priority=' /etc/yum.repos.d/terra.repo; then
        sed -i '/^\[terra\]/a priority=85' /etc/yum.repos.d/terra.repo
    fi
fi

# ── CrowdSec repo ──────────────────────────────────────────────────────────
echo "[01-repos] Adding CrowdSec repo..."
cat > /etc/yum.repos.d/crowdsec.repo <<'EOREPO'
[crowdsec]
name=CrowdSec
baseurl=https://packagecloud.io/crowdsec/crowdsec/rpm_any/rpm_any/$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=0
priority=80
EOREPO

# ── NVIDIA Container Toolkit repo ──────────────────────────────────────────
echo "[01-repos] Adding NVIDIA Container Toolkit repo..."
if ! [ -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]; then
    cat > /etc/yum.repos.d/nvidia-container-toolkit.repo <<'EOREPO'
[nvidia-container-toolkit]
name=NVIDIA Container Toolkit
baseurl=https://nvidia.github.io/libnvidia-container/stable/rpm/$basearch
enabled=0
gpgcheck=1
gpgkey=https://nvidia.github.io/libnvidia-container/gpgkey
EOREPO
fi

echo "[01-repos] Done. ucore base kernel + F44 userspace + RPMFusion + Terra + CrowdSec."
echo "[01-repos] Priority: CrowdSec(80) < Terra(85) < RPMFusion(90) < F44(95) < ucore(99)"