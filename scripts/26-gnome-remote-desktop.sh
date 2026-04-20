#!/usr/bin/env bash
set -euo pipefail

echo "=== Migrating to GNOME Remote Desktop (GNOME 50) ==="

# Pre-emptively disable/mask legacy xrdp services just in case they bleed in from a base image
systemctl mask xrdp.service xrdp-sesman.service 2>/dev/null || true

# GNOME Remote Desktop handles Wayland headless RDP natively.
# Enable the systemd service to prepare the system for headless GDM RDP login.
systemctl enable gnome-remote-desktop.service || true

# Create drop-in to ensure GRD waits for the network to be online
mkdir -p /usr/lib/systemd/system/gnome-remote-desktop.service.d
cat << 'EOF' > /usr/lib/systemd/system/gnome-remote-desktop.service.d/10-network-wait.conf
[Unit]
After=network-online.target
Wants=network-online.target
EOF

# Fix potential permissions on the drop-in
chmod 0644 /usr/lib/systemd/system/gnome-remote-desktop.service.d/10-network-wait.conf

# Ensure internal CloudWS and GRD state directories are pre-created
# Managed via system_files/usr/lib/tmpfiles.d/cloudws-grd.conf

echo "GNOME Remote Desktop provisioning complete."
