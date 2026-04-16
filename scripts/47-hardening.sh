#!/usr/bin/bash
# 47-hardening.sh - selective SecureBlue-style hardening that does NOT break
# NVIDIA, CUDA, Steam, Proton, libvirt, Waydroid. No hardened_malloc globally.
set -euo pipefail

log() { printf '[47-hardening] %s\n' "$*"; }

dnf5 -y install usbguard audit aide policycoreutils policycoreutils-python-utils \
                setools-console libpwquality openscap-scanner scap-security-guide || \
    log "WARN: partial hardening pkg install"

# USBGuard shipped under system_files/ with safe defaults
# (existing devices allowed, new insertions blocked pending approval)
systemctl enable usbguard.service || true
systemctl enable auditd.service   || true

# sysctl hardening drop-in ships under system_files/etc/sysctl.d/
# No action needed here; systemd-sysctl will pick it up on boot.

log "hardening configured (USBGuard, auditd, sysctl drop-ins)"