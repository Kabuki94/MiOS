#!/usr/bin/bash
# 17-cockpit-sysext.sh
# Install Cockpit directly into the bootc image. The sysext path from
# tools/make-sysext upstream is a dev workflow and is NOT SELinux-enforcing-
# policy-complete as of early 2026; for production on bootc we bake Cockpit
# into /usr and optionally layer a sysext at runtime for mixed fleets.
set -euo pipefail

log() { printf '[17-cockpit] %s\n' "$*"; }
: "${DNF:=dnf -y}"

log "installing Cockpit packages"
${DNF} install \
  cockpit cockpit-ws cockpit-bridge cockpit-system \
  cockpit-podman cockpit-storaged cockpit-networkmanager \
  cockpit-selinux cockpit-files cockpit-ostree cockpit-machines

log "enabling cockpit.socket"
systemctl enable cockpit.socket

# Prepare the optional sysext path: merge on boot if any extension has been
# dropped into /var/lib/extensions/.
log "enabling systemd-sysext.service (optional runtime extensions)"
systemctl enable systemd-sysext.service || true

log "Cockpit layer complete"
