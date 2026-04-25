#!/bin/bash
# CloudWS v1.3.0 — 31-user: PAM, user creation, groups, sudoers
# Must run AFTER skel is populated (31-locale-theme writes skel/.bashrc)
# and BEFORE any service that references the user.
set -euo pipefail

echo "——————————————————————?"
echo "  CloudWS v1.3.0 — User & Authentication"
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

echo "[31-user] Creating user ${C_USER} via sysusers..."
if [[ "${C_USER}" != "cloudws" ]]; then
    # Generate dynamic sysusers for custom username
    cat <<EOF > /usr/lib/sysusers.d/15-cloudws-custom.conf
u ${C_USER} - "CloudWS Custom User" /var/home/${C_USER} /bin/bash
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
# Groups are pre-created and memberships injected via /usr/lib/sysusers.d/*.conf
# and processed by systemd-sysusers above. Imperative calls removed.

# — SUDOERS —
# Managed via system_files/usr/lib/sudoers.d/10-cloudws-wheel
chmod 440 /usr/lib/sudoers.d/10-cloudws-wheel 2>/dev/null || true

# — LOCALE —
# Managed via system_files/usr/lib/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# — CLOUD-INIT —
# Managed via system_files/usr/lib/cloud/cloud.cfg.d/10-cloudws.cfg

# — MULTIPATH —
# Managed via system_files/usr/lib/multipath.conf

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
