#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# CloudWS-bootc: Systemd execution analysis & WSL2 Boot Loop fixes
# Resolves ordering cycles, executable stripping, and hardware-dependent
# failure cascades detected during F44 boots on varied hardware/hypervisors.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "==> Applying CloudWS-bootc system service fixes..."

# 1. Fix USBGuard Permissions
# Log trace: Permissions for /etc/usbguard/usbguard-daemon.conf should be 0600
if [ -f /etc/usbguard/usbguard-daemon.conf ]; then
    chmod 0600 /etc/usbguard/usbguard-daemon.conf
fi

# 2. Fix 203/EXEC for custom CloudWS services
# Log trace: cloudws-role.service & cloudws-cdi-detect.service exited 203/EXEC
# Global chmod commands in earlier pipelines stripped execution bits.
find /usr/libexec -name 'cloudws-*' -type f -exec chmod +x {} \; || true
find /usr/bin -name 'cloudws-*' -type f -exec chmod +x {} \; || true

if [ -f /etc/libvirt/hooks/qemu ]; then
    chmod +x /etc/libvirt/hooks/qemu
fi

# 3. Fix systemd-resolved 217/USER
# Log trace: systemd-resolved.service exited 217/USER
# User mapping required at boot time; ensuring it's compiled statically.
if [ -f /usr/lib/sysusers.d/systemd-resolve.conf ]; then
    systemd-sysusers /usr/lib/sysusers.d/systemd-resolve.conf || true
fi

# 4. Fix Systemd Ordering Cycle for GPU Passthrough
# Log trace: sockets.target: Found ordering cycle: docker.socket/start after cloudws-gpu-nvidia.service/start after basic.target
# Default dependencies tangle the GPU loading logic with standard user-level sockets.
mkdir -p /etc/systemd/system/cloudws-gpu-nvidia.service.d/
cat << 'EOF' > /etc/systemd/system/cloudws-gpu-nvidia.service.d/10-cycle-fix.conf
[Unit]
DefaultDependencies=no
Requires=sysinit.target
After=sysinit.target
EOF

# 5. WSL2 Compatibility Gating
# All WSL2 service skips (gdm, firewalld, waydroid-container, nvidia-powerd,
# crowdsec*, dev-binderfs.mount, ceph-bootstrap, audit*, bootloader-update,
# coreos-printk-quiet, coreos-populate-lvmdevices, usbguard) are owned by
# 20-services.sh's WSL_SKIP_SERVICES loop. Drop-ins for dbus-broker / upower
# ship via the system_files overlay. Nothing more to gate here.

# dbus-daemon-wsl.service is shipped via system_files overlay — enable it here
# (preset already lists it, but this guards against a preset-all miss).
systemctl enable dbus-daemon-wsl.service 2>/dev/null || true

# 6. Escape-sequence fix no longer needed here — 36-akmod-guards.sh now writes
# \\\\ in the heredoc so all 7 service drop-ins have correct \\. from the start.
