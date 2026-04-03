#!/bin/bash
# CloudWS — 20-services: Enable all systemd services
set -euo pipefail

# ─── Core services ────────────────────────────────────────────────────────────
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket osbuild-composer.socket sshd.service
systemctl enable tuned.service pmcd.service pmlogger.service pmproxy.service
systemctl enable firewalld.service chronyd.service

# ─── Optional services (fail silently if package wasn't installed) ────────────
if command -v crowdsec &>/dev/null; then
    systemctl enable crowdsec.service 2>/dev/null || true
    systemctl enable crowdsec-firewall-bouncer.service 2>/dev/null || true
fi
systemctl enable fapolicyd.service usbguard.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service hypervvssd.service hypervkvpd.service 2>/dev/null || true
systemctl enable smb.service nmb.service nfs-server.service 2>/dev/null || true
systemctl enable tailscaled.service xrdp.service xrdp-sesman.service 2>/dev/null || true
systemctl enable waydroid-container.service cloud-init.service 2>/dev/null || true
systemctl enable pcsd.service multipathd.service 2>/dev/null || true
systemctl enable podman.socket podman-auto-update.timer podman-restart.service 2>/dev/null || true

# TuneD default profile
tuned-adm profile throughput-performance 2>/dev/null || true

echo "[20-services] All services enabled."
