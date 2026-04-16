#!/usr/bin/bash
# 41-akmods-copy.sh - VERIFICATION ONLY
# ucore-hci:stable-nvidia already ships signed NVIDIA kmods via ublue-os/ucore-kmods.
# No /tmp/akmods-* COPY stages exist in Containerfile anymore (v2.2.4 removed them).
set -euo pipefail

log() { printf '[41-akmods] %s\n' "$*"; }

if rpm -qa 'kmod-nvidia*' 2>/dev/null | grep -q . ; then
    log "OK: NVIDIA kmod(s) from ucore-hci base:"
    rpm -qa 'kmod-nvidia*' | sed 's/^/  /'
else
    log "NOTE: no kmod-nvidia* in base (using fedora-bootc instead of ucore-hci?)"
fi

if compgen -G "/etc/pki/akmods/certs/*.der" > /dev/null; then
    log "OK: MOK cert present:"
    ls -1 /etc/pki/akmods/certs/*.der | sed 's/^/  /'
else
    log "NOTE: no MOK cert at /etc/pki/akmods/certs/*.der"
fi