#!/bin/bash
# MiOS v2.1.0 — Build Artifact Deployment
# Copies build-time logs, manifests, and context hubs to user home directories.
# Runs on first boot or when new artifacts are detected.

set -euo pipefail

ARTIFACT_SRC="/usr/lib/mios"
HUB_SRC="/ai-context.json"
MANIFEST_SRC="/changelogs /specs/knowledge /artifacts"

# Target relative to home
TARGET_SUBDIR="Documents/MiOS/Build-Artifacts"

log_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log()  { printf '[%s] ==> %s\n' "$(log_ts)" "$*"; }
diag() { printf '[%s] DIAG: %s\n' "$(log_ts)" "$*"; }

deploy_to_user() {
    local username="$1"
    local userhome="$2"
    local target_dir="${userhome}/${TARGET_SUBDIR}"

    log "Deploying artifacts to ${username} (${target_dir})..."
    diag "Checking source paths in ${ARTIFACT_SRC}..."
    
    mkdir -p "${target_dir}"

    # Copy build logs
    if [ -d "${ARTIFACT_SRC}/logs" ]; then
        diag "Copying logs to ${target_dir}/logs"
        cp -r "${ARTIFACT_SRC}/logs" "${target_dir}/"
    else
        diag "No logs found in ${ARTIFACT_SRC}/logs"
    fi

    # Copy context hub and manifests
    if [ -f "${HUB_SRC}" ]; then
        diag "Copying context hub ${HUB_SRC}"
        cp "${HUB_SRC}" "${target_dir}/"
    fi

    for dir in ${MANIFEST_SRC}; do
        if [ -d "${dir}" ]; then
            diag "Syncing manifest directory: ${dir}"
            mkdir -p "${target_dir}${dir}"
            cp -r "${dir}"/* "${target_dir}${dir}/"
        fi
    done

    chown -R "${username}:${username}" "${target_dir}"
    log "✓ Success for ${username}"
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
