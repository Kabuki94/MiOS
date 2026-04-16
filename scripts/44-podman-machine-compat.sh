#!/usr/bin/bash
# 44-podman-machine-compat.sh - make this image a valid Podman machine backend
# Users can then: podman machine init --image ghcr.io/kabuki94/cloudws-bootc:latest
set -euo pipefail

log() { printf '[44-podman-machine] %s\n' "$*"; }

dnf5 -y install \
    openssh-server openssh-clients sudo polkit \
    qemu-guest-agent cloud-init wslu \
    podman podman-plugins podman-docker containers-common

# Create the 'core' user (Podman machine convention)
if ! id -u core >/dev/null 2>&1; then
    useradd -m -G wheel -s /bin/bash core
    # Lock the password (key-auth only)
    passwd -l core
fi

# Enable core services (presets will override in boot context anyway)
systemctl enable sshd.service
systemctl enable podman.socket
systemctl enable qemu-guest-agent.service
systemctl enable cloud-init.service
systemctl enable cloud-final.service

log "podman-machine compatibility configured (user=core, sshd:22, cloud-init)"