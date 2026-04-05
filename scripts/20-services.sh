#!/bin/bash
# CloudWS — 20-services: Enable systemd services + bare-metal-only gating
# Services that are only useful on bare metal get ConditionVirtualization=no
# drop-ins so they silently skip in VMs. Eliminates 60-90s boot delays.
set -euo pipefail

# ─── Core services (run everywhere) ──────────────────────────────────────────
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket sshd.service
systemctl enable tuned.service
systemctl enable pmcd.service pmlogger.service pmproxy.service 2>/dev/null || true
if systemctl list-unit-files firewalld.service &>/dev/null; then
    systemctl enable firewalld.service
else
    echo "[20-services] NOTICE: firewalld.service not found — installing..."
    dnf -y install firewalld --skip-unavailable 2>/dev/null || true
    systemctl enable firewalld.service 2>/dev/null || echo "[20-services] WARNING: firewalld still not available"
fi
systemctl enable chronyd.service 2>/dev/null || true

# ─── Optional services (fail silently if package wasn't installed) ────────────
systemctl enable fapolicyd.service usbguard.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service hypervvssd.service hypervkvpd.service 2>/dev/null || true
systemctl enable tailscaled.service 2>/dev/null || true
systemctl enable waydroid-container.service cloud-init.service 2>/dev/null || true
systemctl enable podman.socket podman-auto-update.timer podman-restart.service 2>/dev/null || true
systemctl enable xrdp.service xrdp-sesman.service 2>/dev/null || true

# ─── K3s + Ceph services ─────────────────────────────────────────────────────
systemctl enable k3s.service 2>/dev/null || true
systemctl enable var-home.mount 2>/dev/null || true
systemctl enable var-lib-containers.mount 2>/dev/null || true
systemctl enable ceph-bootstrap.service 2>/dev/null || true

# ─── Bare-metal-only services ────────────────────────────────────────────────
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
    systemctl enable "${svc}.service" 2>/dev/null || true
    DROPIN_DIR="/usr/lib/systemd/system/${svc}.service.d"
    mkdir -p "$DROPIN_DIR"
    cat > "${DROPIN_DIR}/10-bare-metal-only.conf" <<'DROPIN'
[Unit]
# CloudWS: Skip this service in VMs/containers
ConditionVirtualization=no
DROPIN
done

echo "[20-services] Bare-metal-only drop-ins created for: ${BARE_METAL_SERVICES[*]}"

# ─── WSL2-specific service masking ───────────────────────────────────────────
# These services crash-loop or are useless in WSL2 containers
WSL_MASK_SERVICES=(
    gdm
    firewalld
    waydroid-container
    nvidia-powerd
    crowdsec
    crowdsec-firewall-bouncer
    dev-binderfs.mount
    ceph-bootstrap
)

for svc in "${WSL_MASK_SERVICES[@]}"; do
    unit="${svc}"
    [[ "$unit" != *.* ]] && unit="${unit}.service"
    if [ -f "/usr/lib/systemd/system/${unit}" ] || [ -f "/etc/systemd/system/${unit}" ]; then
        mkdir -p "/usr/lib/systemd/system/${unit}.d"
        cat > "/usr/lib/systemd/system/${unit}.d/10-skip-wsl.conf" <<'DROPIN'
[Unit]
# CloudWS: Skip in WSL2 — no binder/display/firewall support
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN
    fi
done
echo "[20-services] WSL2 skip drop-ins installed"

tuned-adm profile throughput-performance 2>/dev/null || true

echo "[20-services] All services enabled (including K3s + Ceph stack)."
