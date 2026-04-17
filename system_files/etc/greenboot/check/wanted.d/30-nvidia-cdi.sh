#!/usr/bin/bash
# Wanted (warning only, not rollback): NVIDIA CDI spec exists when a GPU is present
set -euo pipefail
if compgen -G "/dev/nvidia*" >/dev/null; then
    test -s /var/run/cdi/nvidia.yaml || {
        echo "NVIDIA device present but CDI spec missing"
        exit 1
    }
fi