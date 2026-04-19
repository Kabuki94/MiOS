#!/usr/bin/bash
# 14-gcp-guest-environment.sh
# Install Google Compute Engine guest-environment packages on Fedora bootc.
# Safe to run on non-GCP hosts: agent services are gated by
# ConditionVirtualization=vm and a DMI check via ExecCondition.
set -euo pipefail

# shellcheck source=/dev/null
source /usr/libexec/cloudws/lib/common.sh 2>/dev/null || true
: "${DNF:=dnf -y}"

log() { printf '[14-gcp-guest-env] %s\n' "$*"; }

# Packages available in Fedora 41/42 repos (verified early 2026):
#   google-guest-agent
#   google-compute-engine-guest-configs
#   google-compute-engine-oslogin
# google-osconfig-agent is NOT in Fedora repos; optional via Google YUM repo.

log "installing GCE guest environment packages"
${DNF} install \
  google-guest-agent \
  google-compute-engine-guest-configs \
  google-compute-engine-oslogin

# Agent >=20250901 uses the plugin architecture; manager is the active unit.
log "enabling guest-agent plugin manager + startup/shutdown scripts"
systemctl enable \
  google-guest-agent-manager.service \
  google-startup-scripts.service \
  google-shutdown-scripts.service \
  google-oslogin-cache.timer \
  google-disk-expand.service

# OS Login PAM drop-in is installed by the oslogin package; no edits here.
# nsswitch.conf passwd/group rewriting is done by the agent at runtime.

# Drop a conservative sshd override that REQUIRES OS Login AuthorizedKeysCommand.
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/50-cloudws-gcp.conf <<'EOF'
# Managed by CloudWS-bootc 14-gcp-guest-environment.sh
AuthorizedKeysCommand /usr/bin/google_authorized_keys
AuthorizedKeysCommandUser root
ChallengeResponseAuthentication no
PasswordAuthentication no
PermitRootLogin no
EOF
chmod 0644 /etc/ssh/sshd_config.d/50-cloudws-gcp.conf

log "GCE guest environment layer complete"
