#!/bin/bash
# CloudWS v0.1.3 — 37-selinux: Build-time SELinux policy fixes
# Custom per-rule modules for known Fedora Rawhide / ucore / systemd 260 denials.
#
# ARCHITECTURE: Each policy is a separate module so a missing type only
# affects that specific module (not all of them). Uses VAR=$((VAR + 1))
# not ((VAR++)) which returns exit 1 when VAR=0 under set -euo pipefail.
set -euo pipefail

echo "[37-selinux] Applying SELinux build-time fixes..."

# ═══ Restorecon — fix labels for all major trees ═══
if command -v restorecon &>/dev/null; then
    echo "[37-selinux] Running restorecon on /boot /etc /usr /var..."
    restorecon -R /boot 2>/dev/null || true
    restorecon -R /etc 2>/dev/null || true
    restorecon -R /usr 2>/dev/null || true
    restorecon -R /var 2>/dev/null || true
fi

# ═══ Semanage import — atomic booleans + fcontexts ═══
if command -v semanage &>/dev/null; then
    echo "[37-selinux] Applying SELinux booleans and fcontexts..."
    semanage import <<'EOSEM' 2>/dev/null || true
boolean -m --on container_use_cephfs
boolean -m --on daemons_dump_core
boolean -m --on domain_can_mmap_files
boolean -m --on virt_sandbox_use_all_caps
boolean -m --on virt_use_nfs
boolean -m --on virt_use_samba
boolean -m --on nis_enabled
fcontext -a -t boot_t '/boot/bootupd-state.json'
fcontext -a -t accountsd_var_lib_t '/usr/share/accountsservice/interfaces(/.*)?'
fcontext -a -t ceph_var_lib_t '/var/lib/ceph(/.*)?'
fcontext -a -t ceph_log_t '/var/log/ceph(/.*)?'
EOSEM

    # Apply fcontext labels
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
    restorecon -R /var/lib/ceph 2>/dev/null || true
    restorecon -R /var/log/ceph 2>/dev/null || true
    echo "[37-selinux] ✓ Booleans and fcontexts applied"
else
    echo "[37-selinux] WARNING: semanage not found — install policycoreutils-python-utils"
fi

# ═══ Custom policy modules ═══
if command -v checkmodule &>/dev/null && command -v semodule_package &>/dev/null; then
    echo "[37-selinux] Building custom SELinux policy modules..."

    SELINUX_OK=0
    SELINUX_FAIL=0

    declare -A CLOUDWS_POLICIES

    # bootupctl needs to read /boot/bootupd-state.json (labeled boot_t)
    CLOUDWS_POLICIES[bootupd]='
module cloudws_bootupd 1.0;
require { type boot_t; type bootupd_t; class file { read getattr open }; }
allow bootupd_t boot_t:file { read getattr open };'

    # accounts-daemon reads symlinks in /usr/share/accountsservice/interfaces/
    CLOUDWS_POLICIES[accountsd]='
module cloudws_accountsd 1.0;
require { type accountsd_t; class lnk_file { read getattr }; }
allow accountsd_t self:lnk_file { read getattr };'

    # accounts-daemon watches /usr directories for changes
    CLOUDWS_POLICIES[accountsd_watch]='
module cloudws_accountsd_watch 1.0;
require { type accountsd_t; type usr_t; class dir { watch watch_reads }; }
allow accountsd_t usr_t:dir { watch watch_reads };'

    # systemd-resolved writes to /run/systemd/resolve.hook/ sock_file
    CLOUDWS_POLICIES[resolved]='
module cloudws_resolved 1.0;
require { type systemd_resolved_t; type init_var_run_t; class sock_file write; }
allow systemd_resolved_t init_var_run_t:sock_file write;'

    # fapolicyd writes to xdm socket
    CLOUDWS_POLICIES[fapolicyd]='
module cloudws_fapolicyd 1.0;
require { type fapolicyd_t; type xdm_var_run_t; class sock_file write; }
allow fapolicyd_t xdm_var_run_t:sock_file write;'

    # fapolicyd connects to GDM unix stream socket
    CLOUDWS_POLICIES[fapolicyd_gdm]='
module cloudws_fapolicyd_gdm 1.0;
require { type fapolicyd_t; type xdm_t; class unix_stream_socket connectto; }
allow fapolicyd_t xdm_t:unix_stream_socket connectto;'

    # chcon needs mac_admin capability for relabeling
    CLOUDWS_POLICIES[chcon]='
module cloudws_chcon 1.0;
require { type chcon_t; class capability mac_admin; }
allow chcon_t self:capability mac_admin;'

    # accounts-daemon D-Bus communication with systemd-homed
    CLOUDWS_POLICIES[accountsd_homed]='
module cloudws_accountsd_homed 1.0;
require { type accountsd_t; type systemd_homed_t; class dbus send_msg; }
allow accountsd_t systemd_homed_t:dbus send_msg;
allow systemd_homed_t accountsd_t:dbus send_msg;'

    # systemd-homed needs to read /home (home_root_t on bootc with /var/home)
    CLOUDWS_POLICIES[homed_varhome]='
module cloudws_homed_varhome 1.0;
require { type systemd_homed_t; type home_root_t; class dir { read getattr open search }; }
allow systemd_homed_t home_root_t:dir { read getattr open search };'

    # gdm-session-worker needs write access to .cache directories
    CLOUDWS_POLICIES[gdm_cache]='
module cloudws_gdm_cache 1.0;
require { type xdm_t; type cache_home_t; class dir { add_name write create setattr }; class file { create write open getattr setattr }; }
allow xdm_t cache_home_t:dir { add_name write create setattr };
allow xdm_t cache_home_t:file { create write open getattr setattr };'

    # coreos-boot-mount generator write access
    CLOUDWS_POLICIES[coreos_bootmount]='
module cloudws_coreos_bootmount 1.0;
require { type coreos_boot_mount_generator_t; type systemd_generator_unit_file_t; class dir { write add_name remove_name }; class file { create write open rename unlink }; }
allow coreos_boot_mount_generator_t systemd_generator_unit_file_t:dir { write add_name remove_name };
allow coreos_boot_mount_generator_t systemd_generator_unit_file_t:file { create write open rename unlink };'

    # systemd-portabled D-Bus communication with init
    CLOUDWS_POLICIES[portabled]='
module cloudws_portabled 1.0;
require { type init_t; type systemd_portabled_t; class dbus send_msg; }
allow init_t systemd_portabled_t:dbus send_msg;
allow systemd_portabled_t init_t:dbus send_msg;'

    # Looking Glass KVMFR device access for VMs
    CLOUDWS_POLICIES[kvmfr]='
module cloudws_kvmfr 1.0;
require { type svirt_t; type device_t; class chr_file { open read write map getattr }; }
allow svirt_t device_t:chr_file { open read write map getattr };'

    # Build and install each policy individually
    # v2.1.2: bootupctl /boot/bootupd-state.json access
    CLOUDWS_POLICIES[bootupd_state]='
module cloudws_bootupd_state 1.1;
require { type bootupd_t; type boot_t; class file { read open getattr lock ioctl }; class dir { read open getattr search }; }
allow bootupd_t boot_t:file { read open getattr lock ioctl };
allow bootupd_t boot_t:dir { read open getattr search };'

    # v2.1.2: systemd-resolved hook socket
    CLOUDWS_POLICIES[resolved_hook]='
module cloudws_resolved_hook 1.0;
require { type systemd_resolved_t; type init_t; class unix_stream_socket connectto; class sock_file write; }
allow systemd_resolved_t init_t:unix_stream_socket connectto;
allow systemd_resolved_t init_t:sock_file write;'

    # v2.1.2: accounts-daemon Malcontent WebFilter access
    CLOUDWS_POLICIES[accountsd_malcontent]='
module cloudws_accountsd_malcontent 1.0;
require { type accountsd_t; type usr_t; class lnk_file { read getattr }; class file { read open getattr ioctl }; class dir { read open getattr search }; }
allow accountsd_t usr_t:lnk_file { read getattr };
allow accountsd_t usr_t:file { read open getattr ioctl };
allow accountsd_t usr_t:dir { read open getattr search };'

    # v2.1.2: chcon mac_admin capability
    CLOUDWS_POLICIES[chcon_macadmin]='
module cloudws_chcon_macadmin 1.0;
require { type chcon_t; class capability2 mac_admin; }
allow chcon_t self:capability2 mac_admin;'

    # v2.1.2: gdm-session-worker full .cache access
    CLOUDWS_POLICIES[gdm_session_cache]='
module cloudws_gdm_session_cache 1.0;
require { type xdm_t; type cache_home_t; class dir { add_name write create read open getattr search setattr }; class file { create write read open getattr setattr }; }
allow xdm_t cache_home_t:dir { add_name write create read open getattr search setattr };
allow xdm_t cache_home_t:file { create write read open getattr setattr };'

    for name in "${!CLOUDWS_POLICIES[@]}"; do
        echo "${CLOUDWS_POLICIES[$name]}" > "/tmp/cloudws_${name}.te"
        if checkmodule -M -m -o "/tmp/cloudws_${name}.mod" "/tmp/cloudws_${name}.te" 2>/dev/null && \
           semodule_package -o "/tmp/cloudws_${name}.pp" -m "/tmp/cloudws_${name}.mod" 2>/dev/null && \
           semodule -i "/tmp/cloudws_${name}.pp" 2>/dev/null; then
            echo "[37-selinux] cloudws_${name}: OK"
            SELINUX_OK=$((SELINUX_OK + 1))
        else
            echo "[37-selinux] cloudws_${name}: SKIPPED (type missing in current policy)"
            SELINUX_FAIL=$((SELINUX_FAIL + 1))
        fi
        rm -f "/tmp/cloudws_${name}".{te,mod,pp}
    done

    echo "[37-selinux] ${SELINUX_OK} policies installed, ${SELINUX_FAIL} skipped"
else
    echo "[37-selinux] WARNING: checkmodule/semodule_package not found"
    echo "[37-selinux] Install: selinux-policy-devel (provides checkmodule + semodule_package)"
fi

echo "
# ── Additional SELinux modules for runtime denials (v2.1.1 fixes) ──

# bootupctl accessing /boot/bootupd-state.json (read + open + getattr)
MODNAME=""
MODNAME=""
if seinfo -t bootupd_t 2>/dev/null | grep -q bootupd_t; then
    MODNAME="cloudws_bootupd_state"
    cat > "/tmp/${MODNAME}.te" <<'SEMOD'
module cloudws_bootupd_state 1.1;
require {
    type bootupd_t;
    type boot_t;
    class file { read open getattr lock ioctl };
    class dir { read open getattr search };
}
allow bootupd_t boot_t:file { read open getattr lock ioctl };
allow bootupd_t boot_t:dir { read open getattr search };
SEMOD
    checkmodule -M -m -o "/tmp/${MODNAME}.mod" "/tmp/${MODNAME}.te" 2>/dev/null && \
    semodule_package -o "/tmp/${MODNAME}.pp" -m "/tmp/${MODNAME}.mod" 2>/dev/null && \
    semodule -i "/tmp/${MODNAME}.pp" 2>/dev/null && \
    echo "[37-selinux] ${MODNAME}: OK" || echo "[37-selinux] ${MODNAME}: FAILED"
    if [ -n "${MODNAME:-}" ]; then if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi; fi.{te,mod,pp}
fi

# systemd-resolved writing to resolve.hook socket
MODNAME=""
MODNAME=""
if seinfo -t systemd_resolved_t 2>/dev/null | grep -q systemd_resolved_t; then
    MODNAME="cloudws_resolved_hook"
    cat > "/tmp/${MODNAME}.te" <<'SEMOD'
module cloudws_resolved_hook 1.0;
require {
    type systemd_resolved_t;
    type init_t;
    class unix_stream_socket connectto;
    class sock_file write;
}
allow systemd_resolved_t init_t:unix_stream_socket connectto;
allow systemd_resolved_t init_t:sock_file write;
SEMOD
    checkmodule -M -m -o "/tmp/${MODNAME}.mod" "/tmp/${MODNAME}.te" 2>/dev/null && \
    semodule_package -o "/tmp/${MODNAME}.pp" -m "/tmp/${MODNAME}.mod" 2>/dev/null && \
    semodule -i "/tmp/${MODNAME}.pp" 2>/dev/null && \
    echo "[37-selinux] ${MODNAME}: OK" || echo "[37-selinux] ${MODNAME}: FAILED"
    if [ -n "${MODNAME:-}" ]; then if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi; fi.{te,mod,pp}
fi

# accounts-daemon reading Malcontent WebFilter.xml (lnk_file + file read)
MODNAME=""
MODNAME=""
if seinfo -t accountsd_t 2>/dev/null | grep -q accountsd_t; then
    MODNAME="cloudws_accountsd_malcontent"
    cat > "/tmp/${MODNAME}.te" <<'SEMOD'
module cloudws_accountsd_malcontent 1.0;
require {
    type accountsd_t;
    type usr_t;
    class lnk_file { read getattr };
    class file { read open getattr ioctl };
    class dir { read open getattr search };
}
allow accountsd_t usr_t:lnk_file { read getattr };
allow accountsd_t usr_t:file { read open getattr ioctl };
allow accountsd_t usr_t:dir { read open getattr search };
SEMOD
    checkmodule -M -m -o "/tmp/${MODNAME}.mod" "/tmp/${MODNAME}.te" 2>/dev/null && \
    semodule_package -o "/tmp/${MODNAME}.pp" -m "/tmp/${MODNAME}.mod" 2>/dev/null && \
    semodule -i "/tmp/${MODNAME}.pp" 2>/dev/null && \
    echo "[37-selinux] ${MODNAME}: OK" || echo "[37-selinux] ${MODNAME}: FAILED"
    if [ -n "${MODNAME:-}" ]; then if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi; fi.{te,mod,pp}
fi

# chcon requiring mac_admin capability
MODNAME=""
MODNAME=""
if seinfo -t chcon_t 2>/dev/null | grep -q chcon_t; then
    MODNAME="cloudws_chcon_macadmin"
    cat > "/tmp/${MODNAME}.te" <<'SEMOD'
module cloudws_chcon_macadmin 1.0;
require {
    type chcon_t;
    class capability2 mac_admin;
}
allow chcon_t self:capability2 mac_admin;
SEMOD
    checkmodule -M -m -o "/tmp/${MODNAME}.mod" "/tmp/${MODNAME}.te" 2>/dev/null && \
    semodule_package -o "/tmp/${MODNAME}.pp" -m "/tmp/${MODNAME}.mod" 2>/dev/null && \
    semodule -i "/tmp/${MODNAME}.pp" 2>/dev/null && \
    echo "[37-selinux] ${MODNAME}: OK" || echo "[37-selinux] ${MODNAME}: FAILED"
    if [ -n "${MODNAME:-}" ]; then if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi; fi.{te,mod,pp}
fi

# gdm-session-worker accessing .cache directory (add_name, write, create)
MODNAME=""
MODNAME=""
if seinfo -t xdm_t 2>/dev/null | grep -q xdm_t; then
    MODNAME="cloudws_gdm_session_cache"
    cat > "/tmp/${MODNAME}.te" <<'SEMOD'
module cloudws_gdm_session_cache 1.0;
require {
    type xdm_t;
    type cache_home_t;
    class dir { add_name write create read open getattr search setattr };
    class file { create write read open getattr setattr };
}
allow xdm_t cache_home_t:dir { add_name write create read open getattr search setattr };
allow xdm_t cache_home_t:file { create write read open getattr setattr };
SEMOD
    checkmodule -M -m -o "/tmp/${MODNAME}.mod" "/tmp/${MODNAME}.te" 2>/dev/null && \
    semodule_package -o "/tmp/${MODNAME}.pp" -m "/tmp/${MODNAME}.mod" 2>/dev/null && \
    semodule -i "/tmp/${MODNAME}.pp" 2>/dev/null && \
    echo "[37-selinux] ${MODNAME}: OK" || echo "[37-selinux] ${MODNAME}: FAILED"
    if [ -n "${MODNAME:-}" ]; then if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi; fi.{te,mod,pp}
fi
[37-selinux] SELinux configuration complete."
