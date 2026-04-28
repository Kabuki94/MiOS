#!/bin/bash
# MiOS v0.1.3 - 31-user: PAM, user creation, groups, sudoers
# Must run AFTER skel is populated (31-locale-theme writes skel/.bashrc)
# and BEFORE any service that references the user.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log "User & Authentication Configuration"

# - PAM FIX -
log "Configuring PAM via authselect..."
if command -v authselect &>/dev/null; then
    authselect select local --force 2>/dev/null || {
        warn "authselect failed - using system_files overlay fallback"
    }
fi

# - USER CREATION -
# Password is pre-hashed (SHA-512) by the orchestrator - plaintext NEVER in build log.
# Defaults for CI builds or when environment variables are not provided:
C_USER="mios" # @track:USER_ADMIN
# Note: MIOS_PASSWORD_HASH should be a SHA-512 crypt-style hash
C_HASH="${MIOS_PASSWORD_HASH:-}"

log "Creating user ${C_USER} via sysusers..."
if [[ "${C_USER}" != "mios" ]]; then
    # Generate dynamic sysusers for custom username
    cat <<EOF > /usr/lib/sysusers.d/15-mios-custom.conf
u ${C_USER} - "MiOS Custom User" /var/home/${C_USER} /bin/bash
m ${C_USER} wheel
m ${C_USER} libvirt
m ${C_USER} kvm
m ${C_USER} video
m ${C_USER} render
m ${C_USER} input
m ${C_USER} dialout
m ${C_USER} docker
EOF
fi

# Apply sysusers declarative config
systemd-sysusers --root=/ 2>/dev/null || true

# Validate user creation
if getent passwd "${C_USER}" >/dev/null; then
    log "User ${C_USER} created successfully"
    home=$(getent passwd "${C_USER}" | cut -d: -f6)
    if [ ! -d "$home" ]; then
        log "Creating home directory for ${C_USER} from /etc/skel..."
        mkdir -p "$home"
        cp -a /etc/skel/. "$home/"
    fi

    # -- USER-SPACE DOTFILE INJECTION --
    # Injects personal dotfiles from the build context if provided.
    # Pattern: /ctx/etc/mios/dotfiles/ (mapped from $XDG_CONFIG_HOME/mios/dotfiles/)
    DOTFILE_SRC="/ctx/etc/mios/dotfiles"
    if [[ -d "$DOTFILE_SRC" ]]; then
        log "Injecting user-space dotfiles into ${home}..."
        # Copy files removing the .user suffix if present
        for f in "${DOTFILE_SRC}"/.*; do
            [[ -f "$f" ]] || continue
            basename=$(basename "$f")
            target_name="${basename%.user}"
            cp -v "$f" "${home}/${target_name}"
        done
    fi

    if [[ -n "${C_HASH}" ]]; then
        echo "${C_USER}:${C_HASH}" | chpasswd -e 2>/dev/null || true
        echo "root:${C_HASH}" | chpasswd -e 2>/dev/null || true
    fi
    passwd -u "${C_USER}" 2>/dev/null || true
else
    die "Failed to create user ${C_USER}"
fi

# - GROUP INJECTION -
# Groups are pre-created and memberships injected via /usr/lib/sysusers.d/*.conf
# and processed by systemd-sysusers above. Imperative calls removed.

# - SUDOERS -
# Managed via usr/lib/sudoers.d/10-mios-wheel
chmod 440 /usr/lib/sudoers.d/10-mios-wheel 2>/dev/null || true

# - LOCALE -
# Managed via usr/lib/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# - CLOUD-INIT -
# Managed via usr/lib/cloud/cloud.cfg.d/10-mios.cfg

# - MULTIPATH -
# Managed via usr/lib/multipath.conf

# - FIX HOME DIRECTORY OWNERSHIP -
log "Fixing home directory ownership..."
awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd | while read -r u; do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ -d "$home" ]; then
        uid=$(id -u "$u"); gid=$(id -g "$u")
        chown -R "${uid}:${gid}" "$home"
    fi
done

# - NFS STATE DIRECTORY -
# Managed via usr/lib/tmpfiles.d/mios-nfs.conf

log "User & authentication configured successfully"
