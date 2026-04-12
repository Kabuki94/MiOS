#!/bin/bash
# CloudWS v2.0 — 37-selinux: Build-time SELinux policy fixes
# Custom per-rule modules for known Fedora Rawhide / systemd 260 denials.
set -euo pipefail

echo "[37-selinux] Applying SELinux build-time fixes..."

# ═══ Restorecon — fix labels for all major trees ═══
if command -v restorecon &>/dev/null; then
    restorecon -R /boot /etc /usr /var 2>/dev/null || true
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
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
fi

# ═══ Custom policy modules ═══
# CRITICAL: Use var=$((var + 1)) NOT ((var++)) — the latter returns exit 1
# when the previous value is 0 under set -euo pipefail.
if command -v checkmodule &>/dev/null && command -v semodule_package &>/dev/null; then
    echo "[37-selinux] Building custom SELinux policy modules..."

    SELINUX_OK=0
    SELINUX_FAIL=0

    declare -A CLOUDWS_POLICIES

    CLOUDWS_POLICIES[bootupd]='
module cloudws_bootupd 1.0;
require { type boot_t; type bootupd_t; class file { read getattr open }; }
allow bootupd_t boot_t:file { read getattr open };'

    CLOUDWS_POLICIES[accountsd]='
module cloudws_accountsd 1.0;
require { type accountsd_t; class lnk_file { read getattr }; }
allow accountsd_t self:lnk_file { read getattr };'

    CLOUDWS_POLICIES[resolved]='
module cloudws_resolved 1.0;
require { type systemd_resolved_t; type init_var_run_t; class sock_file write; }
allow systemd_resolved_t init_var_run_t:sock_file write;'

    CLOUDWS_POLICIES[fapolicyd]='
module cloudws_fapolicyd 1.0;
require { type fapolicyd_t; type xdm_var_run_t; class sock_file write; }
allow fapolicyd_t xdm_var_run_t:sock_file write;'

    CLOUDWS_POLICIES[chcon]='
module cloudws_chcon 1.0;
require { type chcon_t; class capability mac_admin; }
allow chcon_t self:capability mac_admin;'

    CLOUDWS_POLICIES[accountsd_homed]='
module cloudws_accountsd_homed 1.0;
require { type accountsd_t; type systemd_homed_t; class dbus send_msg; }
allow accountsd_t systemd_homed_t:dbus send_msg;
allow systemd_homed_t accountsd_t:dbus send_msg;'

    CLOUDWS_POLICIES[accountsd_watch]='
module cloudws_accountsd_watch 1.0;
require { type accountsd_t; type usr_t; class dir { watch watch_reads }; }
allow accountsd_t usr_t:dir { watch watch_reads };'

    CLOUDWS_POLICIES[fapolicyd_gdm]='
module cloudws_fapolicyd_gdm 1.0;
require { type fapolicyd_t; type xdm_t; class unix_stream_socket connectto; }
allow fapolicyd_t xdm_t:unix_stream_socket connectto;'

    CLOUDWS_POLICIES[portabled]='
module cloudws_portabled 1.0;
require { type init_t; type systemd_portabled_t; class dbus send_msg; }
allow init_t systemd_portabled_t:dbus send_msg;
allow systemd_portabled_t init_t:dbus send_msg;'

    CLOUDWS_POLICIES[kvmfr]='
module cloudws_kvmfr 1.0;
require { type svirt_t; type device_t; class chr_file { open read write map getattr }; }
allow svirt_t device_t:chr_file { open read write map getattr };'

    # v2.0: coreos-boot-mount generator write access
    CLOUDWS_POLICIES[coreos_bootmount]='
module cloudws_coreos_bootmount 1.0;
require { type coreos_boot_mount_generator_t; type systemd_generator_unit_file_t; class dir { write add_name remove_name }; class file { create write open rename unlink }; }
allow coreos_boot_mount_generator_t systemd_generator_unit_file_t:dir { write add_name remove_name };
allow coreos_boot_mount_generator_t systemd_generator_unit_file_t:file { create write open rename unlink };'

    # v2.0: gdm-session-worker cache directory access
    CLOUDWS_POLICIES[gdm_cache]='
module cloudws_gdm_cache 1.0;
require { type xdm_t; type cache_home_t; class dir { add_name write create setattr }; class file { create write open getattr setattr }; }
allow xdm_t cache_home_t:dir { add_name write create setattr };
allow xdm_t cache_home_t:file { create write open getattr setattr };'

    # v2.0: systemd-homed read access on /home (var_home_t on bootc)
    CLOUDWS_POLICIES[homed_varhome]='
module cloudws_homed_varhome 1.0;
require { type systemd_homed_t; type home_root_t; class dir { read getattr open search }; }
allow systemd_homed_t home_root_t:dir { read getattr open search };'

    for name in "${!CLOUDWS_POLICIES[@]}"; do
        echo "${CLOUDWS_POLICIES[$name]}" > "/tmp/cloudws_${name}.te"
        if checkmodule -M -m -o "/tmp/cloudws_${name}.mod" "/tmp/cloudws_${name}.te" 2>/dev/null && \
           semodule_package -o "/tmp/cloudws_${name}.pp" -m "/tmp/cloudws_${name}.mod" 2>/dev/null && \
           semodule -i "/tmp/cloudws_${name}.pp" 2>/dev/null; then
            echo "[37-selinux] cloudws_${name}: OK"
            SELINUX_OK=$((SELINUX_OK + 1))
        else
            echo "[37-selinux] cloudws_${name}: SKIPPED (type missing)"
            SELINUX_FAIL=$((SELINUX_FAIL + 1))
        fi
        rm -f "/tmp/cloudws_${name}".{te,mod,pp}
    done

    echo "[37-selinux] ${SELINUX_OK} policies installed, ${SELINUX_FAIL} skipped"
fi

echo "[37-selinux] SELinux configuration complete."
