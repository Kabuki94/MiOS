#!/bin/bash
# MiOS v2.1.0 — 32-hostname: Unique per-instance hostname
#
# Strategy: Set a template hostname in the image. On first boot, systemd
# generates /etc/machine-id. The mios-init service (35-init-service.sh)
# derives a stable 5-char tag from machine-id and sets the hostname.
#
# Result: Each instance gets mios-XXXXX (e.g., mios-a3f9c), unique
# per deployment, stable across reboots.
set -euo pipefail

echo "[32-hostname] Setting default hostname template..."

# Default hostname for the image — overwritten on first boot by mios-init
echo "mios" > /etc/hostname

echo "[32-hostname] Hostname will become mios-XXXXX on first boot."
