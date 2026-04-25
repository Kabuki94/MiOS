#!/bin/bash
# MiOS v2.1.0 — Upstream Source Synchronization
# Fetches the latest 'main' branch root FS from GitHub and populates user folders.
# Runs on first boot after network is online.

set -euo pipefail

UPSTREAM_URL="https://github.com/Kabuki94/MiOS/archive/refs/heads/main.tar.gz"
TARGET_SUBDIR="Documents/MiOS/Upstream-Source"

sync_to_user() {
    local username="$1"
    local userhome="$2"
    local target_dir="${userhome}/${TARGET_SUBDIR}"
    local temp_tar="/tmp/mios-upstream-${username}.tar.gz"

    echo "Syncing upstream source to ${username} (${target_dir})..."
    
    mkdir -p "${target_dir}"

    # Download latest archive
    if curl -L -o "${temp_tar}" "${UPSTREAM_URL}"; then
        # Extract and strip the top-level directory (MiOS-main)
        tar -xzf "${temp_tar}" -C "${target_dir}" --strip-components=1
        rm -f "${temp_tar}"
        
        # Ensure correct ownership
        chown -R "${username}:${username}" "${target_dir}"
        echo "✓ Success for ${username}"
    else
        echo "✗ Failed to download upstream source for ${username}"
        return 1
    fi
}

# Find all human users (UID >= 1000, excluding nobody)
mapfile -t USERS < <(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1":"$6}')

for userinfo in "${USERS[@]}"; do
    IFS=":" read -r username userhome <<< "$userinfo"
    if [[ "$userhome" == /home/* ]]; then
        sync_to_user "$username" "$userhome" || true
    fi
done

# Mark as done
touch /var/lib/mios-upstream-synced
