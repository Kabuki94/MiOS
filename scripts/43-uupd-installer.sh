#!/usr/bin/bash
# 43-uupd-installer.sh - install uupd as the unified updater; disable competitors
set -euo pipefail

log() { printf '[43-uupd] %s\n' "$*"; }

# Enable ublue-os/packages COPR and install uupd
dnf5 -y copr enable ublue-os/packages || true
dnf5 -y install uupd

# Disable the updaters uupd supersedes (so they do not race)
systemctl disable bootc-fetch-apply-updates.timer 2>/dev/null || true
systemctl disable rpm-ostreed-automatic.timer     2>/dev/null || true

# Enable uupd.timer (shipped by the package)
systemctl enable uupd.timer

log "uupd installed; bootc-fetch-apply-updates and rpm-ostreed-automatic disabled"