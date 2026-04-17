#!/usr/bin/bash
# Wanted (warning only, not rollback): NVIDIA CDI spec exists when a GPU is present
set -euo pipefail
if ls /dev/nvidia* 2>/dev/null | grep -q .; then
    test -s /var/run/cdi/nvidia.yaml || {
        echo "NVIDIA device present but CDI spec missing"
        exit 1
    }
fi