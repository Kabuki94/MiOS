#!/usr/bin/env bash
set -euo pipefail
# CloudWS v2.1.4 — Post-pivot root filesystem verification
# Validates critical paths exist after ostree/composefs mount.
# If verification fails, logs error but does NOT block boot
# (future: trigger rollback via bootc).

CRITICAL_PATHS=(
    /usr/lib/modules
    /usr/bin/podman
    /usr/bin/bootc
    /usr/sbin/gdm
    /usr/lib/systemd/system/gdm.service
    /usr/lib/systemd/system/cockpit.socket
    /usr/lib/bootc/kargs.d/00-cloudws.toml
)

MISSING=0
for path in "${CRITICAL_PATHS[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "cloudws-verify: MISSING $path" | systemd-cat -t cloudws-verify -p err
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    echo "cloudws-verify: $MISSING critical paths missing — image may be corrupt" \
        | systemd-cat -t cloudws-verify -p crit
    # Future: bootc rollback --queue
    exit 1
fi

echo "cloudws-verify: all critical paths present" | systemd-cat -t cloudws-verify -p info
exit 0