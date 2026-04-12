#!/bin/bash
# CloudWS v2.0 — 32-hostname: Unique per-instance hostname
#
# Strategy: Set a template hostname in the image. On first boot, systemd
# generates /etc/machine-id. The cloudws-init service (35-init-service.sh)
# derives a stable 5-char tag from machine-id and sets the hostname.
#
# Result: Each instance gets cloudws-XXXXX (e.g., cloudws-a3f9c), unique
# per deployment, stable across reboots.
set -euo pipefail

echo "[32-hostname] Setting default hostname template..."

# Default hostname for the image — overwritten on first boot by cloudws-init
echo "cloudws" > /etc/hostname

echo "[32-hostname] Hostname will become cloudws-XXXXX on first boot."
