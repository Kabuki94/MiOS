# 47-hardening.sh
---

#!/usr/bin/bash
# 47-hardening.sh - enable hardening services (USBGuard, auditd).
# Package installs moved to PACKAGES.md (packages-security).
# sysctl drop-in shipped via system_files/usr/lib/sysctl.d/99-mios-hardening.conf.
set -euo pipefail

log() { printf '[47-hardening] %s\n' "$*"; }

# USBGuard config is at /usr/lib/usbguard/usbguard-daemon.conf (managed via overlay).
chmod 0600 /usr/lib/usbguard/usbguard-daemon.conf 2>/dev/null || true
systemctl enable usbguard.service 2>/dev/null || log "note: usbguard not installed"
systemctl enable auditd.service   2>/dev/null || log "note: auditd not installed"
systemctl enable fapolicyd.service 2>/dev/null || log "note: fapolicyd not installed"

# Pre-generate fapolicyd trust database for bootc systems
# fapolicyd config is at /usr/lib/fapolicyd/fapolicyd.conf (managed via overlay).
if command -v fagenrules &>/dev/null; then
    log "Pre-generating fapolicyd trust database..."
    # Ensure correct permissions for the fapolicyd directory
    chown -R fapolicyd:fapolicyd /etc/fapolicyd 2>/dev/null || true
    fagenrules --load 2>/dev/null || true
    fapolicyd-cli --update 2>/dev/null || true
fi

log "hardening services wired"