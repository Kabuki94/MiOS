#!/usr/bin/bash
# 16-vdi-stack.sh
# Install the browser-native VDI dependencies (Podman + nginx utilities).
# The actual container services are defined as Podman Quadlets in
# /etc/containers/systemd/; this script only ensures the base tools are
# present and that cloudws-vdi.target is enabled.
set -euo pipefail

log() { printf '[16-vdi-stack] %s\n' "$*"; }
: "${DNF:=dnf -y}"

log "installing VDI host dependencies"
${DNF} install podman crun policycoreutils-python-utils jq

# Quadlet generator is part of Podman; ensure the auto-update timer is enabled
# so AutoUpdate=registry on the Quadlets actually fires.
log "enabling podman-auto-update.timer"
systemctl enable podman-auto-update.timer

log "enabling cloudws-vdi.target"
systemctl enable cloudws-vdi.target

# Validate Quadlet files parse at build time (best-effort; real check is at boot).
if command -v /usr/libexec/podman/quadlet >/dev/null 2>&1; then
  log "validating Quadlets"
  /usr/libexec/podman/quadlet -dryrun -no-kmsg-log /etc/containers/systemd \
    >/tmp/quadlet.log 2>&1 || {
      log "Quadlet dryrun reported errors:"
      cat /tmp/quadlet.log
      exit 1
    }
fi

log "VDI stack layer complete"
