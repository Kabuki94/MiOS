#!/bin/bash
# CloudWS v2.0 ? 31-user: PAM, user creation, groups, sudoers
# Must run AFTER skel is populated (31-locale-theme writes skel/.bashrc)
# and BEFORE any service that references the user.
set -euo pipefail

echo "???????????????????????????????????????????????????????????????????"
echo "  CloudWS v2.0 ? User & Authentication"
echo "???????????????????????????????????????????????????????????????????"

# ??? PAM FIX ???
echo "[31-user] Configuring PAM via authselect..."
if command -v authselect &>/dev/null; then
    authselect select local --force 2>/dev/null || {
        echo "[31-user] WARNING: authselect failed ? applying manual pam_unix fallback"
        for pf in system-auth password-auth; do
            cat > "/etc/pam.d/${pf}" <<'EOPAM'
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        required      pam_deny.so
account     required      pam_unix.so
password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password    required      pam_deny.so
session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
EOPAM
        done
    }
fi

# ??? USER CREATION ???
# Password is pre-hashed (SHA-512) by the orchestrator ? plaintext NEVER in build log.
echo "[31-user] Creating user cloudws..."
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
echo "INJ_U:INJ_HASH" | chpasswd -e
echo "root:INJ_HASH" | chpasswd -e
passwd -u INJ_U 2>/dev/null || true

# ??? GROUP INJECTION ???
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
    if getent group "$g" >/dev/null 2>&1; then
        usermod -aG "$g" INJ_U 2>/dev/null || true
    fi
done

# ??? SUDOERS ???
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-cloudws-wheel
chmod 440 /etc/sudoers.d/10-cloudws-wheel

# ??? LOCALE ???
echo "LANG=en_US.UTF-8" > /etc/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# ??? CLOUD-INIT ???
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-cloudws.cfg <<'EOCI'
preserve_hostname: false
ssh_pwauth: true
system_info:
  default_user:
    name: cloudws
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel, libvirt, kvm, video, render
datasource_list: [NoCloud, None, Azure, GCE, Ec2, Openstack]
EOCI

# ??? MULTIPATH ???
mkdir -p /etc/multipath
cat > /etc/multipath.conf <<'EOMP'
defaults {
    user_friendly_names yes
    find_multipaths yes
}
EOMP

# ??? FIX HOME DIRECTORY OWNERSHIP ???
echo "[31-user] Fixing home directory ownership..."
awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd | while read -r u; do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ -d "$home" ]; then
        uid=$(id -u "$u"); gid=$(id -g "$u")
        chown -R "${uid}:${gid}" "$home"
    fi
done

# ??? NFS STATE DIRECTORY ???
mkdir -p /var/lib/nfs/statd
cat > /usr/lib/tmpfiles.d/cloudws-nfs.conf <<'EOTMP'
d /var/lib/nfs/statd 0755 rpcuser rpcuser -
EOTMP

echo "[31-user] User & authentication configured."
