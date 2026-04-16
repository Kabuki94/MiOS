#!/usr/bin/bash
# 44-podman-machine-compat.sh - Podman-machine backend compatibility.
# Package installs moved to PACKAGES.md (packages-containers, packages-utils).
# This script only does the runtime config that cannot be expressed as packages:
#   - create the 'core' user (Podman machine convention)
#   - enable services needed for machine backend operation
set -euo pipefail

log() { printf '[44-podman-machine] %s\n' "$*"; }

# Create the 'core' user if missing (Podman machine convention).
# Passwordless sudo via /etc/sudoers.d/wheel-nopasswd (shipped in system_files).
if ! id -u core >/dev/null 2>&1; then
    useradd -m -G wheel,libvirt,kvm,video,render -s /bin/bash core
    passwd -l core
    log "created user 'core' (wheel; key-auth only)"
fi

# Enable core services for Podman-machine and cloud-init entry
for unit in \
    sshd.service \
    podman.socket \
    qemu-guest-agent.service \
    cloud-init.service \
    cloud-final.service
do
    systemctl enable "$unit" 2>/dev/null || log "WARN: could not enable $unit (not installed?)"
done

log "podman-machine compatibility wired"