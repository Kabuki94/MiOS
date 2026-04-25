# 43-uupd-installer.sh
---

#!/usr/bin/bash
# 43-uupd-installer.sh - install uupd + greenboot (from PACKAGES.md
# packages-updater section) and disable the updaters it supersedes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/packages.sh"

log() { printf '[43-uupd] %s\n' "$*"; }

# COPR already enabled by 05-enable-external-repos.sh (runs earlier)
install_packages "updater"

# Disable the updaters uupd supersedes
systemctl disable bootc-fetch-apply-updates.timer 2>/dev/null || true
systemctl disable rpm-ostreed-automatic.timer     2>/dev/null || true

# Enable uupd.timer (shipped by the package)
systemctl enable uupd.timer 2>/dev/null || log "WARN: uupd.timer not present (uupd install may have failed)"

log "uupd configured; bootc-fetch-apply-updates.timer and rpm-ostreed-automatic.timer disabled"