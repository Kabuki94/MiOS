#!/usr/bin/bash
# 47-hardening.sh - enable hardening services (USBGuard, auditd).
# Package installs moved to PACKAGES.md (packages-security).
# sysctl drop-in shipped via system_files/etc/sysctl.d/99-cloudws-hardening.conf.
set -euo pipefail

log() { printf '[47-hardening] %s\n' "$*"; }

systemctl enable usbguard.service 2>/dev/null || log "note: usbguard not installed"
systemctl enable auditd.service   2>/dev/null || log "note: auditd not installed"
systemctl enable fapolicyd.service 2>/dev/null || log "note: fapolicyd not installed"

log "hardening services wired"