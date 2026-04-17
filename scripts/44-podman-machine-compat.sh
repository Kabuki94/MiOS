#!/usr/bin/bash
# 44-podman-machine-compat.sh - Podman-machine backend compatibility.
# Package installs moved to PACKAGES.md (packages-containers, packages-utils).
# This script only does the runtime config that cannot be expressed as packages:
#   - create the 'core' user (Podman machine convention)
#   - enable services needed for machine backend operation
#
# v2.2.8 fix:
#   - Pre-create the `video`, `render`, `kvm`, `libvirt` groups if missing so
#     useradd -G doesn't die with "group does not exist". The ucore-hci base
#     ships udev rules that create these groups dynamically at runtime, but
#     during the image build they're absent.
set -euo pipefail

log() { printf '[44-podman-machine] %s\n' "$*"; }

# --- Ensure groups referenced by useradd -G exist --------------------------
# These groups are normally created by udev/systemd-sysusers at runtime. In
# the buildroot they may be absent. Create them with their conventional GIDs
# (matching Fedora defaults) so the user lands in the right group once udev
# materializes the devices at runtime.
for group_spec in "kvm:36" "render:$(getent group render | cut -d: -f3 || echo 105)" "video:$(getent group video | cut -d: -f3 || echo 39)" "libvirt:$(getent group libvirt | cut -d: -f3 || echo)"; do
    name="${group_spec%%:*}"
    gid="${group_spec##*:}"
    if ! getent group "$name" >/dev/null 2>&1; then
        if [[ -n "$gid" ]]; then
            groupadd -r -g "$gid" "$name" 2>/dev/null || groupadd -r "$name" || log "WARN: could not create group $name"
        else
            groupadd -r "$name" || log "WARN: could not create group $name"
        fi
        log "created group '$name'"
    fi
done

# Create the 'core' user if missing (Podman machine convention).
# Passwordless sudo via /etc/sudoers.d/wheel-nopasswd (shipped in system_files).
# Use --groups with only groups that definitely exist; the others are joined
# defensively via usermod -aG so a single missing group doesn't fail the user
# creation entirely.
if ! id -u core >/dev/null 2>&1; then
    useradd -m -G wheel -s /bin/bash core
    passwd -l core
    log "created user 'core' (wheel; key-auth only)"

    for g in libvirt kvm video render; do
        if getent group "$g" >/dev/null 2>&1; then
            usermod -aG "$g" core && log "  added core to $g"
        else
            log "  skipped $g (group still missing)"
        fi
    done
fi

# Enable core services for Podman-machine and cloud-init entry
for unit in \
    sshd.service \
    podman.socket \
    qemu-guest-agent.service \
    cloud-init.service \
    cloud-final.service
do
    systemctl enable "$unit" 2>/dev/null || log "WARN: could not enable $unit (not installed?)"
done

log "podman-machine compatibility wired"
