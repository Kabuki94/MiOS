#!/usr/bin/bash
# Required: cloudws-role.service must have succeeded
set -euo pipefail
systemctl is-active --quiet cloudws-role.service || {
    echo "cloudws-role.service is not active"
    exit 1
}
test -f /var/lib/cloudws/role.active