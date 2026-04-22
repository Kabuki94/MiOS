#!/bin/bash
# CloudWS v0.1.8 — 20-services: Enable systemd services + bare-metal/VM gating
#
# CHANGELOG v1.3:
#   - systemd 260: cgroup v1 support REMOVED — all services must use cgroup v2
#   - systemd 260: SysV service scripts no longer supported
#   - Fixed: pmcd/pmlogger services removed (only pmproxy is installed)
#   - Added: bootloader-update.service for bootc systems
#   - Added: podman-auto-update.timer for quadlet auto-updates
#   - Improved: Bare-metal vs VM vs WSL2 service gating
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════"
echo "  CloudWS v0.1.8 — Service Configuration"
echo "═══════════════════════════════════════════════════════════════════"

# ─── Fix systemd unit file permissions ────────────────────────────────────────
# Container builds sometimes leave bad perms from COPY operations.
for unit_file in \
    /etc/systemd/system/var-home.mount \
    /etc/systemd/system/var-lib-containers.mount \
    /etc/systemd/system/ceph-bootstrap.service \
    /etc/systemd/system/cockpit.socket.d/listen.conf \
; do
    [ -f "$unit_file" ] && chmod 644 "$unit_file"
done
echo "[20-services] Fixed systemd unit file permissions"

# ─── Core services (always enabled) ──────────────────────────────────────────
CORE_SERVICES=(
    # Desktop
    gdm
    NetworkManager
    # Virtualization
    libvirtd.socket
    virtnetworkd.socket
    virtqemud.socket
    # Management
    cockpit.socket
    sshd
    # System
    tuned
    chronyd
    firewalld
    systemd-resolved
    # Containers
    podman.socket
    podman-auto-update.timer
    # Monitoring (only pmproxy — pmcd/pmlogger are NOT installed)
    pmproxy
    # Boot
    bootloader-update
)

for svc in "${CORE_SERVICES[@]}"; do
    systemctl enable "${svc}.service" 2>/dev/null || \
    systemctl enable "${svc}.socket" 2>/dev/null || \
    systemctl enable "${svc}.timer" 2>/dev/null || \
    systemctl enable "${svc}" 2>/dev/null || true
done
echo "[20-services] Core services enabled: ${CORE_SERVICES[*]}"

# ─── Optional services (fail-silent — package may not be installed) ──────────
OPTIONAL_SERVICES=(
    crowdsec
    crowdsec-firewall-bouncer
    fapolicyd
    usbguard
    libvirt-guests
    smb
    nmb
    nfs-server
    rpcbind
    tailscaled
    waydroid-container
    cloud-init
    cloud-init-local
    cloud-config
    cloud-final
)

for svc in "${OPTIONAL_SERVICES[@]}"; do
    systemctl enable "${svc}.service" 2>/dev/null || true
done
echo "[20-services] Optional services enabled (where available)"

# ─── Bare-metal-only services ────────────────────────────────────────────────
# These services should NOT run in VMs or containers.
BARE_METAL_SERVICES=(
    nfs-server
    smb
    nmb
    pacemaker
    corosync
    pcsd
    cloudws-ha-bootstrap
    crowdsec
    crowdsec-firewall-bouncer
    multipathd
    osbuild-composer
    osbuild-worker@1
)

for svc in "${BARE_METAL_SERVICES[@]}"; do
    systemctl enable "${svc}.service" 2>/dev/null || true
done
echo "[20-services] Bare-metal-only services enabled"

# ─── WSL2 & Container Service Gating ─────────────────────────────────────────
# These services skip OCI/WSL2 via drop-ins in system_files overlay.
VIRT_SKIP_SERVICES=(
    gdm
    firewalld
    waydroid-container
    nvidia-powerd
    fapolicyd
    dev-binderfs.mount
    ceph-bootstrap
    auditd
    audit-rules
    bootloader-update
    coreos-printk-quiet
    coreos-populate-lvmdevices
    usbguard
    chronyd
    tuned
)
echo "[20-services] WSL2/Container skip drop-ins active via overlay"

# ─── Container-specific additional skips ────────────────────────────────────
# Services that might work in WSL2 but are strictly redundant in OCI.
CONTAINER_ONLY_SKIP=(
    NetworkManager
    systemd-resolved
)
echo "[20-services] Container-only skip drop-ins active via overlay"


# ─── nvidia-powerd: skip in ALL VMs (no physical NVIDIA GPU) ─────────────────
# Drop-in handled via overlay.


# ─── TuneD: set throughput-performance profile ──────────────────────────────
tuned-adm profile throughput-performance 2>/dev/null || true

echo "[20-services] All services enabled and gated. v1.3 complete."
