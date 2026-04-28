#!/usr/bin/env bash
# MiOS v0.1.3 - 25-firewall-ports: Configure firewalld ports for MiOS services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log "Configuring firewalld ports for MiOS services..."

# During an OCI container build, the firewalld daemon is not running.
# We MUST use firewall-offline-cmd to write directly to the XML policy files.

# Check if firewall-offline-cmd exists
if ! command -v firewall-offline-cmd &>/dev/null; then
    warn "firewall-offline-cmd not found, skipping port configuration"
    exit 0
fi

# Open essential ports for local/LAN access
log "Adding firewall ports..."
firewall-offline-cmd --zone=public --add-port=8080/tcp  # Guacamole / Unified AI Proxy
firewall-offline-cmd --zone=public --add-port=11434/tcp # Ollama
firewall-offline-cmd --zone=public --add-port=8443/tcp  # Ceph Dashboard
firewall-offline-cmd --zone=public --add-port=6443/tcp  # K3s API
firewall-offline-cmd --zone=public --add-port=3389/tcp  # RDP
firewall-offline-cmd --zone=public --add-service=ssh
firewall-offline-cmd --zone=public --add-service=cockpit
firewall-offline-cmd --zone=public --add-service=mios-pxe || true

log "Firewalld port configuration complete"
