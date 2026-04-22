#!/usr/bin/env bash
set -euo pipefail

echo "=== Migrating to GNOME Remote Desktop (GNOME 50) ==="

# Pre-emptively disable/mask legacy xrdp services just in case they bleed in from a base image
systemctl mask xrdp.service xrdp-sesman.service 2>/dev/null || true

# GNOME Remote Desktop handles Wayland headless RDP natively.
# Enable the systemd service to prepare the system for headless GDM RDP login.
systemctl enable gnome-remote-desktop.service || true

# Note: 10-network-wait.conf drop-in is delivered via system_files overlay.
# State directories are pre-created via system_files/usr/lib/tmpfiles.d/cloudws-grd.conf

echo "GNOME Remote Desktop provisioning complete."
