#!/bin/bash
# MiOS v2.1.0 — Build Artifact Deployment
# Copies build-time logs, manifests, and context hubs to user home directories.
# Runs on first boot or when new artifacts are detected.

set -euo pipefail

ARTIFACT_SRC="/usr/lib/mios"
HUB_SRC="/ai-context.json"
MANIFEST_SRC="/changelogs /docs/knowledge /artifacts"

# Target relative to home
TARGET_SUBDIR="Documents/MiOS/Build-Artifacts"

deploy_to_user() {
    local username="$1"
    local userhome="$2"
    local target_dir="${userhome}/${TARGET_SUBDIR}"

    echo "Deploying artifacts to ${username} (${target_dir})..."
    
    mkdir -p "${target_dir}"

    # Copy build logs
    if [ -d "${ARTIFACT_SRC}/logs" ]; then
        cp -r "${ARTIFACT_SRC}/logs" "${target_dir}/"
    fi

    # Copy context hub and manifests
    if [ -f "${HUB_SRC}" ]; then
        cp "${HUB_SRC}" "${target_dir}/"
    fi

    for dir in ${MANIFEST_SRC}; do
        if [ -d "${dir}" ]; then
            # We want the content but flattened or structured? 
            # Let's keep the structure for the user.
            mkdir -p "${target_dir}${dir}"
            cp -r "${dir}"/* "${target_dir}${dir}/"
        fi
    done

    # Ensure correct ownership
    chown -R "${username}:${username}" "${target_dir}"
    echo "✓ Success for ${username}"
}

# Find all human users (UID >= 1000, excluding nobody)
# Filter for users with a home directory in /home
mapfile -t USERS < <(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1":"$6}')

for userinfo in "${USERS[@]}"; do
    IFS=":" read -r username userhome <<< "$userinfo"
    if [[ "$userhome" == /home/* ]]; then
        deploy_to_user "$username" "$userhome"
    fi
done

# Mark as done
touch /var/lib/mios-artifacts-deployed
