#!/bin/bash
# CloudWS — 20-services: Enable systemd services + bare-metal-only gating
# Services that are only useful on bare metal (NFS, HA, CrowdSec, VFIO-related)
# get ConditionVirtualization=no drop-ins so they silently skip in VMs.
# This eliminates 60-90+ seconds of boot delays in Hyper-V/QEMU/VMware.
set -euo pipefail

# ─── Core services (run everywhere) ──────────────────────────────────────────
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket sshd.service
systemctl enable tuned.service pmcd.service pmlogger.service pmproxy.service
systemctl enable firewalld.service chronyd.service

# ─── Optional services (fail silently if package wasn't installed) ────────────
systemctl enable fapolicyd.service usbguard.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service hypervvssd.service hypervkvpd.service 2>/dev/null || true
systemctl enable tailscaled.service 2>/dev/null || true
systemctl enable waydroid-container.service cloud-init.service 2>/dev/null || true
systemctl enable podman.socket podman-auto-update.timer podman-restart.service 2>/dev/null || true
systemctl enable xrdp.service xrdp-sesman.service 2>/dev/null || true

# ─── Bare-metal-only services ────────────────────────────────────────────────
# These services cause boot hangs or are useless in VMs:
#   - nfs-server: waits 60s for network-online.target + RPC registration
#   - smb/nmb: Samba file sharing, pointless in a VM
#   - pacemaker/corosync/pcsd: HA clustering, fails without cluster interfaces
#   - crowdsec + bouncer: IPS, needs firewalld/nftables (absent in WSL2/containers)
#   - multipathd: SAN multipath, no physical disks in VMs
#   - osbuild-composer: image build service, bare-metal dev tool only
#
# ConditionVirtualization=no means "only start when NOT in a VM/container".
# On Hyper-V, systemd-detect-virt returns "microsoft" → condition fails → skip.
# On bare metal, it returns empty → condition passes → service starts normally.
# The service shows "skipped" status (not "failed") — clean journal output.

BARE_METAL_SERVICES=(
    nfs-server
    smb
    nmb
    pacemaker
    corosync
    pcsd
    crowdsec
    crowdsec-firewall-bouncer
    multipathd
    osbuild-composer
    osbuild-worker@1
)

for svc in "${BARE_METAL_SERVICES[@]}"; do
    # Enable the service (so it's active on bare metal)
    systemctl enable "${svc}.service" 2>/dev/null || true

    # Create drop-in: only start on bare metal (ConditionVirtualization=no)
    DROPIN_DIR="/usr/lib/systemd/system/${svc}.service.d"
    mkdir -p "$DROPIN_DIR"
    cat > "${DROPIN_DIR}/10-bare-metal-only.conf" <<'DROPIN'
[Unit]
# CloudWS: Skip this service in VMs/containers — it causes boot delays
# or has no function without physical hardware. Remove this drop-in to
# force-enable in VMs: rm /usr/lib/systemd/system/<service>.d/10-bare-metal-only.conf
ConditionVirtualization=no
DROPIN
done

echo "[20-services] Bare-metal-only drop-ins created for: ${BARE_METAL_SERVICES[*]}"

# TuneD default profile
tuned-adm profile throughput-performance 2>/dev/null || true

echo "[20-services] All services enabled."
