#!/bin/bash
# CloudWS v2.0 — 32-hostname: Unique per-instance hostname
#
# Uses systemd's built-in hostname wildcard feature (v249+):
# Each '?' in /etc/hostname is replaced by a hex char derived from /etc/machine-id.
# Result: cloudws-92a9f (deterministic per machine-id, stable across reboots).
#
# The /etc/machine-id MUST be empty in the container image so that each
# deployment generates a unique one on first boot (ConditionFirstBoot=yes).
set -euo pipefail

echo "[32-hostname] Setting hostname template: cloudws-?????"

# Template hostname — each ? expands from machine-id on first boot
echo "cloudws-?????" > /etc/hostname

# Ensure machine-id is empty in the image (bootc best practice)
# systemd will populate it on first boot from DMI, container UUID, or random
: > /etc/machine-id

echo "[32-hostname] Each deployment will get a unique hostname (e.g., cloudws-a3f9c)."
