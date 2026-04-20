#!/usr/bin/bash
# 48-role-system.sh - install all role-capable packages and wire role switcher.
# Every capability is INSTALLED. Role determines what is ENABLED at boot.
set -euo pipefail

log() { printf '[48-role-system] %s\n' "$*"; }

# Role switcher service + targets + ujust recipes ship via system_files.
# This script just ensures the unit preset references them correctly.

# Enable cloudws-role.service unconditionally; it runs early and sets
# the default target based on /etc/cloudws/role.conf or kernel cmdline.
systemctl enable cloudws-role.service
systemctl enable cloudws-firstboot.target || true

# Default target is chosen by cloudws-role.service on each boot.
# If role.conf is missing, it picks `desktop` (safe default).
# We MUST set the baked default target here. Relying on a runtime service
# to modify /etc/systemd/system/default.target mid-boot creates OSTree
# 3-way merge conflicts and fails to affect the active first-boot transaction.
systemctl set-default graphical.target

log "role system wired (cloudws-role.service enabled)"
