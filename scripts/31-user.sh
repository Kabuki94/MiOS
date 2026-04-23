#!/bin/bash
# CloudWS v0.1.8 — 31-user: PAM, user creation, groups, sudoers
# Must run AFTER skel is populated (31-locale-theme writes skel/.bashrc)
# and BEFORE any service that references the user.
set -euo pipefail

echo "——————————————————————?"
echo "  CloudWS v0.1.8 — User & Authentication"
echo "——————————————————————?"

# — PAM FIX —
echo "[31-user] Configuring PAM via authselect..."
if command -v authselect &>/dev/null; then
    authselect select local --force 2>/dev/null || {
        echo "[31-user] WARNING: authselect failed — using system_files overlay fallback"
    }
fi

# — USER CREATION —
# Password is pre-hashed (SHA-512) by the orchestrator — plaintext NEVER in build log.
# Defaults for CI builds or when environment variables are not provided:
C_USER="${CLOUDWS_USER:-cloudws}"
# Note: CLOUDWS_PASSWORD_HASH should be a SHA-512 crypt-style hash
C_HASH="${CLOUDWS_PASSWORD_HASH:-}"

echo "[31-user] Creating user ${C_USER}..."
if ! getent passwd "${C_USER}" >/dev/null; then
    useradd -m -d "/var/home/${C_USER}" -s /bin/bash "${C_USER}" 2>/dev/null || true
fi

if getent passwd "${C_USER}" >/dev/null; then
    if [[ -n "${C_HASH}" ]]; then
        echo "${C_USER}:${C_HASH}" | chpasswd -e 2>/dev/null || true
        echo "root:${C_HASH}" | chpasswd -e 2>/dev/null || true
    fi
    passwd -u "${C_USER}" 2>/dev/null || true
else
    echo "[31-user] ERROR: Failed to create user ${C_USER}"
fi

# — GROUP INJECTION —
# Pre-create hardware groups with standard Fedora GIDs if missing.
# This prevents dynamic GID drift that breaks udev device assignments.
for group_spec in "kvm:36" "video:39" "render:105" "libvirt:" "input:" "dialout:" "docker:"; do
    name="${group_spec%%:*}"
    gid="${group_spec##*:}"
    if ! getent group "$name" >/dev/null 2>&1; then
        if [ -n "$gid" ]; then
            groupadd -r -g "$gid" "$name" 2>/dev/null || groupadd -r "$name" || true
        else
            groupadd -r "$name" 2>/dev/null || true
        fi
    fi
done

for g in wheel libvirt kvm video render input dialout docker; do
    if getent group "$g" >/dev/null 2>&1 && getent passwd "${C_USER}" >/dev/null; then
        usermod -aG "$g" "${C_USER}" 2>/dev/null || true
    fi
done

# — SUDOERS —
# Managed via system_files/etc/sudoers.d/10-cloudws-wheel
chmod 440 /etc/sudoers.d/10-cloudws-wheel 2>/dev/null || true

# — LOCALE —
# Managed via system_files/etc/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# — CLOUD-INIT —
# Managed via system_files/etc/cloud/cloud.cfg.d/10-cloudws.cfg

# — MULTIPATH —
# Managed via system_files/etc/multipath.conf

# — FIX HOME DIRECTORY OWNERSHIP —
echo "[31-user] Fixing home directory ownership..."
awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd | while read -r u; do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ -d "$home" ]; then
        uid=$(id -u "$u"); gid=$(id -g "$u")
        chown -R "${uid}:${gid}" "$home"
    fi
done

# — NFS STATE DIRECTORY —
# Managed via system_files/usr/lib/tmpfiles.d/cloudws-nfs.conf

echo "[31-user] User & authentication configured."
