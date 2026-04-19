#!/usr/bin/bash
# 15-cloud-init.sh
# Install and enable cloud-init with the GCE datasource pinned.
# cloud-init coexists with google-guest-agent when configured so that
# guest-agent owns SSH keys (via AuthorizedKeysCommand) and cloud-init
# owns hostname, growpart, runcmd, and user_data scripts.
set -euo pipefail

log() { printf '[15-cloud-init] %s\n' "$*"; }
: "${DNF:=dnf -y}"

log "installing cloud-init"
${DNF} install cloud-init cloud-utils-growpart

log "enabling cloud-init services"
systemctl enable \
  cloud-init-local.service \
  cloud-init.service \
  cloud-config.service \
  cloud-final.service

# cloud.cfg.d pinning drop-in is shipped via system_files/; confirm it lands.
if [[ ! -f /etc/cloud/cloud.cfg.d/99-cloudws-gcp.cfg ]]; then
  log "WARNING: /etc/cloud/cloud.cfg.d/99-cloudws-gcp.cfg missing"
fi

log "cloud-init layer complete"
