#!/bin/bash
# CloudWS — 99-overrides: User, PAM, hostname, firewall, GPU, tools, SELinux
# This script uses INJ_U and INJ_P placeholders replaced by the orchestrator.
set -euo pipefail

# ═══ 0. PAM AUTHENTICATION — NUCLEAR-GRADE FIX ═══
authselect select local --force
echo "[99-overrides] authselect: local profile selected"

if ! grep -q "pam_unix.so" /etc/pam.d/password-auth 2>/dev/null; then
    echo "[99-overrides] WARNING: authselect did not produce valid password-auth — writing manual PAM config"
    cat > /etc/pam.d/password-auth <<'EOFPAM'
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        required      pam_deny.so
account     required      pam_unix.so
password    sufficient    pam_unix.so try_first_pass use_authtok nullok sha512 shadow
password    required      pam_deny.so
session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     required      pam_unix.so
EOFPAM
    cp /etc/pam.d/password-auth /etc/pam.d/system-auth
fi
echo "[99-overrides] PAM verification: $(grep -c pam_unix /etc/pam.d/password-auth) pam_unix entries in password-auth"

# ═══ 1. CREATE USER ═══
mkdir -p /var/home /var/roothome
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
echo "INJ_U:INJ_P" | chpasswd
echo "root:INJ_P" | chpasswd
passwd -u INJ_U 2>/dev/null || true
passwd -u root 2>/dev/null || true
echo "[99-overrides] shadow: $(getent shadow INJ_U | cut -d: -f1-2 | cut -c1-30)..."

# ═══ 2. INDESTRUCTIBLE GROUP INJECTION ═══
for g in wheel libvirt kvm video render input dialout; do
    groupadd -f "$g" 2>/dev/null || true
    if ! grep -q "^${g}:.*INJ_U" /etc/group; then
        sed -i "/^${g}:/ s/$/,INJ_U/" /etc/group
        sed -i "/^${g}:/ s/,:,/,/g; /^${g}:/ s/:,/:/g; /^${g}:/ s/,,/,/g" /etc/group
    fi
done

# ═══ 3. SUDOERS ═══
sed -i 's/^# %wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel; chmod 440 /etc/sudoers.d/wheel

# ═══ 4. FULL CLOUDWS CLI + FASTFETCH + ALIASES ═══
cat >> /etc/skel/.bashrc <<'EOBASHRC'

# ─── CloudWS Terminal Customization ──────────────────────────────────────────
alias scan-malware="podman run --rm -v ~/.clamav:/var/lib/clamav -v /var/home:/scandir:ro docker.io/clamav/clamav:latest clamscan -r /scandir"

cloudws() {
    case "${1:-}" in
        --help|-h|help)
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  CloudWS v1.2 — Cloud Workstation OS                       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "  cloudws --help             This help message"
            echo "  cloudws-update             Update OS from registry"
            echo "  cloudws-rebuild            Clone repo → build → push"
            echo "  cloudws-build              Build CloudWS locally (Linux)"
            echo "  cloudws-backup             Backup volumes, K3s, VMs, /var/home"
            echo "  cloudws-deploy <type>      Deploy VM or container from image"
            echo "  cloudws-ceph status        Ceph cluster status"
            echo "  cloudws-ceph dashboard     Ceph Dashboard URL"
            echo "  cloudws-ceph bootstrap     Manual Ceph bootstrap"
            echo "  cloudws-k3s-join           Show K3s join instructions"
            echo "  cloudws-vfio-toggle        GPU VFIO bind/unbind/status/list"
            echo "  cloudws-hostname           Show/set cluster hostname"
            echo "  iommu-groups               Show IOMMU group assignments"
            echo "  scan-malware               On-demand ClamAV scan"
            echo ""
            echo "  sudo bootc status          Deployment info"
            echo "  sudo bootc rollback        Revert to previous image"
            echo "  sudo bootc upgrade         Pull latest from registry"
            echo "  fastfetch                  System overview"
            echo ""
            echo "    https://localhost:8443    Ceph Dashboard"
            echo "    https://localhost:9090    Cockpit web dashboard"
            echo "    https://localhost:26000   iVentoy PXE server"
            echo "    virt-manager             Virtual machine manager"
            echo "    podman ps                Running containers"
            echo "    kubectl get pods         K3s workloads"
            echo "    pcs status               HA cluster status"
            echo ""
            echo "  Suppress fastfetch: export CLOUDWS_NO_FASTFETCH=1"
            ;;
        *) echo "Usage: cloudws {--help}  — try: cloudws --help" ;;
    esac
}

# fastfetch on terminal open (suppress with CLOUDWS_NO_FASTFETCH=1)
if command -v fastfetch &>/dev/null && [ -t 0 ] && [ -z "${CLOUDWS_NO_FASTFETCH:-}" ]; then
    fastfetch
fi
EOBASHRC

if [ -d /var/home/INJ_U ]; then
    cp /etc/skel/.bashrc /var/home/INJ_U/.bashrc 2>/dev/null || true
    chown INJ_U:INJ_U /var/home/INJ_U/.bashrc 2>/dev/null || true
fi

# ═══ 5. LOCALE ═══
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# ═══ 6. DYNAMIC HOSTNAME (HA-safe) ═══
SHORT_ID=$(cat /etc/machine-id 2>/dev/null | head -c6 || echo "000000")
HOSTNAME="CloudWS-${SHORT_ID}"
echo "$HOSTNAME" > /etc/hostname
echo -e "127.0.0.1 localhost\n127.0.1.1 $HOSTNAME ${HOSTNAME}.local\n::1 localhost" > /etc/hosts
echo -e "PRETTY_HOSTNAME=\"CloudWS\"\nICON_NAME=\"computer\"\nCHASSIS=\"server\"" > /etc/machine-info
mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\nhostname-mode=none" > /etc/NetworkManager/conf.d/hostname.conf

cat > /usr/lib/systemd/system/cloudws-hostname.service <<'EOSVC'
[Unit]
Description=Enforce CloudWS Dynamic Hostname
After=local-fs.target
Before=systemd-hostnamed.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'ID=$(cat /etc/machine-id | head -c6); HN="CloudWS-${ID}"; echo "$HN" > /etc/hostname; hostnamectl set-hostname "$HN" 2>/dev/null || true'
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOSVC
systemctl enable cloudws-hostname.service

# ═══ 7. CLOUD-INIT CONFIG ═══
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-cloudws.cfg <<'EOCI'
preserve_hostname: true
manage_etc_hosts: false
ssh_pwauth: true
disable_root: false
system_info:
  default_user:
    name: INJ_U
    lock_passwd: false
    gecos: CloudWS User
    groups: [wheel, libvirt, kvm, video, render, input, dialout]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
datasource_list: [NoCloud, ConfigDrive, OpenStack, Ec2, GCE, Azure, None]
EOCI

# ═══ 8. MULTIPATH CONFIG ═══
cat > /etc/multipath.conf <<'EOMP'
defaults {
    user_friendly_names yes
    find_multipaths yes
    polling_interval 10
}
EOMP

# ═══ 9. FIREWALL INIT ═══
cat > /usr/libexec/cloudws-firewall-init <<'EOFW'
#!/bin/bash
if ! command -v firewall-cmd &>/dev/null; then exit 0; fi
if ! systemctl is-active firewalld &>/dev/null; then exit 0; fi
firewall-cmd --set-default-zone=drop 2>/dev/null || true
firewall-cmd --permanent --zone=drop --add-service=cockpit
firewall-cmd --permanent --zone=drop --add-service=ssh
firewall-cmd --permanent --zone=drop --add-service=mdns
firewall-cmd --permanent --zone=drop --add-port=3389/tcp
firewall-cmd --permanent --zone=drop --add-port=3390/tcp
firewall-cmd --permanent --zone=drop --add-service=samba
firewall-cmd --permanent --zone=drop --add-service=nfs
firewall-cmd --permanent --zone=drop --add-service=rpc-bind
firewall-cmd --permanent --zone=drop --add-service=mountd
firewall-cmd --permanent --zone=drop --add-port=16509/tcp
firewall-cmd --permanent --zone=drop --add-port=5900-5999/tcp
firewall-cmd --permanent --zone=drop --add-port=6443/tcp
firewall-cmd --permanent --zone=drop --add-port=10250/tcp
firewall-cmd --permanent --zone=drop --add-port=2224/tcp
firewall-cmd --permanent --zone=drop --add-port=5403-5405/udp
firewall-cmd --permanent --zone=drop --add-port=26000/tcp
# Ceph ports (MON msgr1/msgr2, OSD/MDS daemon range, Dashboard)
firewall-cmd --permanent --zone=drop --add-port=3300/tcp
firewall-cmd --permanent --zone=drop --add-port=6789/tcp
firewall-cmd --permanent --zone=drop --add-port=6800-7300/tcp
firewall-cmd --permanent --zone=drop --add-port=8443/tcp
# K3s Flannel VXLAN
firewall-cmd --permanent --zone=drop --add-port=8472/udp
firewall-cmd --permanent --zone=trusted --add-interface=lo
firewall-cmd --permanent --zone=trusted --add-interface=podman0
firewall-cmd --permanent --zone=trusted --add-interface=virbr0
firewall-cmd --permanent --zone=trusted --add-interface=cni0
firewall-cmd --permanent --zone=trusted --add-interface=flannel.1
firewall-cmd --permanent --zone=trusted --add-interface=waydroid0
firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
firewall-cmd --permanent --zone=trusted --add-source=10.88.0.0/16
firewall-cmd --permanent --zone=trusted --add-source=192.168.122.0/24
firewall-cmd --permanent --zone=trusted --add-source=192.168.124.0/24
firewall-cmd --permanent --zone=trusted --add-source=127.0.0.0/8
firewall-cmd --reload
echo "[cloudws-firewall-init] Configured"
EOFW
chmod +x /usr/libexec/cloudws-firewall-init

# ═══ 10. GPU AUTO-DETECT SERVICE ═══
cat > /usr/lib/systemd/system/cloudws-gpu-detect.service <<'EOGPUSVC'
[Unit]
Description=CloudWS GPU Environment Detection
DefaultDependencies=no
Before=gdm.service display-manager.service systemd-modules-load.service
After=local-fs.target systemd-udevd.service
ConditionPathExists=!/run/cloudws-gpu-detected
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-gpu-detect
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOGPUSVC

cat > /usr/libexec/cloudws-gpu-detect <<'EOGPU'
#!/bin/bash
set -euo pipefail
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
echo "[cloudws-gpu-detect] Virtualization: $VIRT"

NVIDIA_CONF="/etc/modprobe.d/99-cloudws-virt-gpu.conf"
ENV_DIR="/etc/environment.d"
RENDERER_CONF="${ENV_DIR}/60-cloudws-renderer.conf"
mkdir -p "$ENV_DIR"

if [ "$VIRT" != "none" ]; then
    echo "[cloudws-gpu-detect] VM detected ($VIRT) — blocking NVIDIA"
    cat > "$NVIDIA_CONF" <<'EOMOD'
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nvidia_uvm /bin/false
EOMOD
    for mod in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    # GTK4/libadwaita renderer fix for VMs without GPU
    # Hyper-V, QEMU, VMware all lack hardware 3D. GTK4's Vulkan/NGL
    # renderers produce broken styling under llvmpipe. Force Cairo.
    cat > "$RENDERER_CONF" <<'EORENDER'
GSK_RENDERER=cairo
GDK_DISABLE=vulkan
EORENDER
    echo "[cloudws-gpu-detect] Renderer forced to Cairo (no GPU in VM)"

    case "$VIRT" in
        microsoft|wsl) modprobe hyperv_drm 2>/dev/null || true ;;
        kvm|qemu)      modprobe virtio-gpu 2>/dev/null || true ;;
        vmware)        modprobe vmwgfx 2>/dev/null || true ;;
    esac
else
    echo "[cloudws-gpu-detect] Bare metal — NVIDIA enabled, hardware renderer"
    rm -f "$NVIDIA_CONF"
    rm -f "$RENDERER_CONF"
fi

touch /run/cloudws-gpu-detected
EOGPU
chmod +x /usr/libexec/cloudws-gpu-detect
systemctl enable cloudws-gpu-detect.service

# ═══ 11. EVERY-BOOT INIT SERVICE ═══
cat > /usr/lib/systemd/system/cloudws-init.service <<'EOSVC'
[Unit]
Description=CloudWS System Init
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-init
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOSVC

cat > /usr/libexec/cloudws-init <<'EOINIT'
#!/bin/bash
set -euo pipefail

# Dynamic hostname from machine-id
ID=$(cat /etc/machine-id | head -c6)
hostnamectl set-hostname "CloudWS-${ID}" 2>/dev/null || true

# Ensure home directories exist (bootc /var/home)
for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ ! -d "$home" ]; then
        mkdir -p "$home"
        cp -a /etc/skel/. "$home/" 2>/dev/null || true
        for d in Desktop Documents Downloads Music Pictures Public Templates Videos; do
            mkdir -p "$home/$d"
        done
        chown -R "$u:$u" "$home"; chmod 700 "$home"
    fi
    su - "$u" -c "xdg-user-dirs-update" 2>/dev/null || true
done

# Regenerate groups
for g in wheel libvirt kvm video render input dialout; do
    groupadd -f "$g" 2>/dev/null || true
    for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
        usermod -aG "$g" "$u" 2>/dev/null || true
    done
done

# Firewall init
/usr/libexec/cloudws-firewall-init 2>/dev/null || true

# CrowdSec first-boot registration
if command -v cscli &>/dev/null; then
    cscli machines add -a --force 2>/dev/null || true
    if ! cscli bouncers list 2>/dev/null | grep -q "cs-firewall-bouncer"; then
        BKEY=$(cscli bouncers add cs-firewall-bouncer -o raw 2>/dev/null) || true
        if [ -n "${BKEY:-}" ] && [ -f /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml ]; then
            sed -i "s|^api_key:.*|api_key: ${BKEY}|" /etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml
            systemctl restart crowdsec-firewall-bouncer 2>/dev/null || true
        fi
    fi
fi

# PCP metrics
if command -v pmlogger_check &>/dev/null; then
    mkdir -p /var/log/pcp/pmlogger
    systemctl restart pmcd pmlogger pmproxy 2>/dev/null || true
fi

# Flatpak dark theme — use ADW_DEBUG_COLOR_SCHEME, NOT GTK_THEME
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
flatpak update --appstream 2>/dev/null || true

# Hyper-V Enhanced Session auto-setup (xRDP vsock)
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
if [ "$VIRT" = "microsoft" ] && [ -f /etc/xrdp/xrdp.ini ]; then
    # Configure xRDP for vsock transport (Hyper-V Enhanced Session)
    if ! grep -q "use_vsock=true" /etc/xrdp/xrdp.ini; then
        sed -i 's/^use_vsock=.*/use_vsock=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
        sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
        sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true
        sed -i 's/^bitmap_compression=.*/bitmap_compression=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
    fi
    # Configure xRDP session to use GNOME Wayland
    if [ -f /etc/xrdp/startwm.sh ]; then
        if ! grep -q "CLOUDWS_XRDP" /etc/xrdp/startwm.sh; then
            cat >> /etc/xrdp/startwm.sh <<'EOXRDP'

# CLOUDWS_XRDP: Hyper-V Enhanced Session → GNOME
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=gnome
export GNOME_SHELL_SESSION_MODE=ubuntu
exec gnome-session 2>/dev/null || exec gnome-session-classic 2>/dev/null || exec /etc/X11/Xsession
EOXRDP
        fi
    fi
    systemctl enable --now xrdp xrdp-sesman 2>/dev/null || true
    echo "[cloudws-init] Hyper-V Enhanced Session enabled (xRDP vsock)"
fi

bootc status 2>/dev/null || true
echo "[cloudws-init] System initialization complete."
EOINIT
chmod +x /usr/libexec/cloudws-init
systemctl enable cloudws-init.service

# ═══ 12. CUSTOM TOOLS ═══

# cloudws-vfio-toggle
cat > /usr/local/bin/cloudws-vfio-toggle <<'EOVFIO'
#!/bin/bash
case "${1:-}" in
    list)
        echo "=== IOMMU Groups ==="
        for g in /sys/kernel/iommu_groups/*/devices/*; do
            echo "Group $(basename $(dirname $(dirname $g))): $(lspci -nns ${g##*/})"
        done ;;
    bind|unbind|status) driverctl "$@" ;;
    *) echo "Usage: cloudws-vfio-toggle {list|bind|unbind|status} [device]" ;;
esac
EOVFIO
chmod +x /usr/local/bin/cloudws-vfio-toggle

# iommu-groups
cat > /usr/local/bin/iommu-groups <<'EOIOMMU'
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo -e "\033[1;34mIOMMU Group ${g##*/}:\033[0m"
    for d in "$g"/devices/*; do echo "  $(lspci -nns "${d##*/}")"; done
done
EOIOMMU
chmod +x /usr/local/bin/iommu-groups

# cloudws-update — uses bootc upgrade with proper error handling
cat > /usr/local/bin/cloudws-update <<'EOUPD'
#!/bin/bash
set -euo pipefail
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS Update — Checking for new image from registry     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Show current status
echo "Current deployment:"
bootc status 2>/dev/null | head -20
echo ""

# Try upgrade (pulls new image if digest differs)
echo "Checking registry for updates..."
if bootc upgrade 2>&1; then
    echo ""
    echo "✓ Update staged. Reboot to apply."
    echo "  Rollback anytime: sudo bootc rollback"
else
    RC=$?
    echo ""
    if [ $RC -eq 77 ]; then
        echo "✓ Already up to date — no new image available."
    else
        echo "⚠ bootc upgrade failed (exit $RC)."
        echo "  Check: bootc status"
        echo "  Fix origin: sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest"
    fi
fi
EOUPD
chmod +x /usr/local/bin/cloudws-update

# cloudws-rebuild — clone, build, push from deployed system
cat > /usr/local/bin/cloudws-rebuild <<'EOREBUILD'
#!/bin/bash
set -euo pipefail
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS Rebuild — Clone → Build → Push                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git clone https://github.com/Kabuki94/CloudWS-bootc.git .
echo "Building image..."
podman build --squash-all --no-cache -t ghcr.io/kabuki94/cloudws-bootc:latest .
echo "Pushing to GHCR..."
podman push ghcr.io/kabuki94/cloudws-bootc:latest
echo "✓ Rebuild complete. Run: cloudws-update"
cd /; rm -rf "$TMPDIR"
EOREBUILD
chmod +x /usr/local/bin/cloudws-rebuild

# cloudws-build — local build wrapper
cat > /usr/local/bin/cloudws-build <<'EOBUILD'
#!/bin/bash
set -euo pipefail
echo "Building CloudWS image locally..."
podman build --squash-all --no-cache -t cloudws-bootc:local .
echo "✓ Local build complete: cloudws-bootc:local"
EOBUILD
chmod +x /usr/local/bin/cloudws-build

# cloudws-backup — backup critical data
cat > /usr/local/bin/cloudws-backup <<'EOBACKUP'
#!/bin/bash
set -euo pipefail
STAMP=$(date +%Y%m%d-%H%M%S)
DEST="/var/home/cloudws-backup-${STAMP}"
mkdir -p "$DEST"
echo "Backing up to $DEST..."
cp -a /var/home/ "$DEST/home/" 2>/dev/null || true
podman volume export --all "$DEST/podman-volumes.tar" 2>/dev/null || true
if command -v kubectl &>/dev/null; then
    kubectl get all -A -o yaml > "$DEST/k3s-resources.yaml" 2>/dev/null || true
fi
echo "✓ Backup complete: $DEST"
EOBACKUP
chmod +x /usr/local/bin/cloudws-backup

# cloudws-deploy — deploy VM or container from image
cat > /usr/local/bin/cloudws-deploy <<'EODEPLOY'
#!/bin/bash
case "${1:-}" in
    vm)
        echo "Deploying CloudWS VM via virt-install..."
        echo "Use: virt-install --import --disk path=/path/to/cloudws.raw --os-variant fedora-rawhide"
        ;;
    container)
        echo "Running CloudWS container..."
        podman run -d --name cloudws ghcr.io/kabuki94/cloudws-bootc:latest
        ;;
    *)
        echo "Usage: cloudws-deploy {vm|container}"
        ;;
esac
EODEPLOY
chmod +x /usr/local/bin/cloudws-deploy

# cloudws-hostname — show/set cluster hostname
cat > /usr/local/bin/cloudws-hostname <<'EOHOST'
#!/bin/bash
case "${1:-}" in
    set)
        if [ -n "${2:-}" ]; then
            hostnamectl set-hostname "$2"
            echo "Hostname set to: $2"
        else
            echo "Usage: cloudws-hostname set <name>"
        fi ;;
    *)
        echo "Hostname: $(hostname)"
        echo "Machine ID: $(cat /etc/machine-id)"
        bootc status 2>/dev/null | head -5
        ;;
esac
EOHOST
chmod +x /usr/local/bin/cloudws-hostname

# cloudws-ceph — Ceph cluster status and management
cat > /usr/local/bin/cloudws-ceph <<'EOCEPH'
#!/bin/bash
case "${1:-}" in
    status)
        if [ -f /var/lib/ceph/.bootstrapped ]; then
            echo "Ceph cluster: BOOTSTRAPPED"
            cephadm shell -- ceph status 2>/dev/null || echo "  (daemons may be starting)"
        else
            echo "Ceph cluster: NOT BOOTSTRAPPED"
            echo "  Bootstrap runs on first bare-metal boot, or run:"
            echo "  sudo /usr/local/bin/ceph-bootstrap.sh"
        fi ;;
    dashboard)
        IP=$(hostname -I | awk '{print $1}')
        echo "Ceph Dashboard: https://${IP}:8443"
        echo "  Admin password: check /var/log/ceph/cephadm.log" ;;
    bootstrap)
        echo "Running Ceph bootstrap manually..."
        sudo /usr/local/bin/ceph-bootstrap.sh ;;
    join)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            echo "Usage: cloudws-ceph join <hostname> <ip>"
        else
            echo "Adding host ${2} (${3}) to Ceph cluster..."
            ceph cephadm get-pub-key | ssh root@${3} tee -a /root/.ssh/authorized_keys
            ceph orch host add "${2}" "${3}" --labels=osd
        fi ;;
    *)
        echo "Usage: cloudws-ceph {status|dashboard|bootstrap|join <host> <ip>}" ;;
esac
EOCEPH
chmod +x /usr/local/bin/cloudws-ceph

# cloudws-k3s-join — join a container/WSL2 instance to the K3s cluster
cat > /usr/local/bin/cloudws-k3s-join <<'EOK3S'
#!/bin/bash
if [ -z "${1:-}" ]; then
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  CloudWS K3s Cluster Join                                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    if [ -f /var/lib/rancher/k3s/server/node-token ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
        TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
        echo "  This host is a K3s SERVER."
        echo ""
        echo "  To join another CloudWS instance (container/WSL2/bare metal):"
        echo "    k3s agent --server https://${SERVER_IP}:6443 \\"
        echo "      --token ${TOKEN} \\"
        echo "      --node-name \$(hostname)"
        echo ""
        echo "  Or via Podman on the host:"
        echo "    sudo podman run -d --privileged --network host \\"
        echo "      -e K3S_URL=https://${SERVER_IP}:6443 \\"
        echo "      -e K3S_TOKEN=${TOKEN} \\"
        echo "      -e K3S_NODE_NAME=k3s-agent-container \\"
        echo "      rancher/k3s:v1.31.6-k3s1 agent"
    else
        echo "  K3s server not running on this host."
        echo "  Start it: sudo systemctl start k3s"
    fi
else
    SERVER_URL="$1"
    TOKEN="${2:-}"
    NODE="${3:-$(hostname)}"
    if [ -z "$TOKEN" ]; then
        echo "Usage: cloudws-k3s-join <server-url> <token> [node-name]"
        exit 1
    fi
    echo "Joining K3s cluster at $SERVER_URL as $NODE..."
    exec k3s agent --server "$SERVER_URL" --token "$TOKEN" --node-name "$NODE"
fi
EOK3S
chmod +x /usr/local/bin/cloudws-k3s-join

# Cockpit .desktop entry (for app grid)
cat > /usr/share/applications/cockpit.desktop <<'EOCD'
[Desktop Entry]
Type=Application
Name=Cockpit
Comment=CloudWS Server Management Dashboard
Exec=gio open http://localhost:9090
Icon=cockpit
Categories=System;
Keywords=server;management;dashboard;web;
EOCD

# ═══ 13. DESKTOP BLOAT CLEANUP ═══
# Wine utility apps are NO LONGER hidden — they go into the "Wine" dconf folder.
# Only genuinely unwanted items (tour, malcontent, system internals, duplicates) hidden.
# Do NOT hide useful GNOME apps — they either go in folders (via dconf) or
# aren't installed at all (handled by PACKAGES.md).
echo "[99-overrides] Hiding bloat from app grid..."
OVERRIDE_DIR="/usr/share/applications"
for entry in \
    "org.gnome.Tour.desktop" \
    "org.freedesktop.MalcontentControl.desktop" \
    "gamemode-simulate-game.desktop" \
    "nvidia-settings.desktop" \
    "nvidia-smi.desktop" \
    "wine.desktop" \
    "wine-help.desktop" \
    "wine-winehelp.desktop" \
    "wine-mime-msi.desktop" \
    "wine-browsedrive.desktop" \
    "wine-extension-chm.desktop" \
    "wine-extension-hlp.desktop" \
    "wine-extension-ini.desktop" \
    "wine-extension-vbs.desktop" \
    "yelp.desktop" \
    "xterm.desktop" \
    "bvnc.desktop" \
    "bssh.desktop" \
    "avahi-discover.desktop" \
    "qv4l2.desktop" \
    "qvidcap.desktop" \
    "org.gnome.Epiphany.WebAppProvider.desktop" \
    "org.gnome.IconBrowser4.desktop" \
    "gtk4-icon-browser.desktop" \
    "gtk4-widget-factory.desktop" \
    "gtk4-demo.desktop" \
    "gtk4-print-editor.desktop" \
    "gtk4-node-editor.desktop" \
    "gamt.desktop" \
    "org.gnome.tweaks.desktop" \
    "ibus-setup.desktop" \
    "setroubleshoot.desktop" \
    "yad-icon-browser.desktop" \
    "fluid-soundfont-gm.desktop" \
    "lstopo.desktop" \
    "cmake-gui.desktop" \
    "qdbusviewer.desktop" \
; do
    cat > "${OVERRIDE_DIR}/${entry}" <<EODT
[Desktop Entry]
Type=Application
Name=Hidden
NoDisplay=true
EODT
done

# ═══ 14. NFS STATE DIRECTORY (fixes rpc.statd error) ═══
mkdir -p /var/lib/nfs/statd
cat > /usr/lib/tmpfiles.d/cloudws-nfs.conf <<'EOTMP'
d /var/lib/nfs/statd 0755 rpcuser rpcuser -
EOTMP

# ═══ 15. VM-SPECIFIC SERVICE GATING (via ConditionVirtualization drop-ins) ═══
# GDM: only skip in WSL2 (Hyper-V VMs with a display SHOULD run GDM)
mkdir -p /usr/lib/systemd/system/gdm.service.d
cat > /usr/lib/systemd/system/gdm.service.d/10-skip-wsl.conf <<'DROPIN'
[Unit]
# CloudWS: Skip GDM in WSL2 — WSLg provides display server
# Hyper-V VMs still get GDM (they have hyperv_drm framebuffer)
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN

# nvidia-powerd: skip in ALL VMs (no physical NVIDIA GPU)
if [ -f /usr/lib/systemd/system/nvidia-powerd.service ]; then
    mkdir -p /usr/lib/systemd/system/nvidia-powerd.service.d
    cat > /usr/lib/systemd/system/nvidia-powerd.service.d/10-bare-metal-only.conf <<'DROPIN'
[Unit]
ConditionVirtualization=no
DROPIN
fi

# Waydroid + binder: skip in WSL2 (no binder/ashmem support)
for svc in waydroid-container dev-binderfs.mount; do
    if [ -f "/usr/lib/systemd/system/${svc}" ] || [ -f "/usr/lib/systemd/system/${svc}.service" ]; then
        unit="${svc}"
        [[ "$unit" != *.* ]] && unit="${unit}.service"
        mkdir -p "/usr/lib/systemd/system/${unit}.d"
        cat > "/usr/lib/systemd/system/${unit}.d/10-skip-wsl.conf" <<'DROPIN'
[Unit]
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN
    fi
done

echo "[99-overrides] VM-specific service drop-ins installed"

# ═══ 15b. HYPER-V ENHANCED SESSION — FIRST-BOOT AUTO-ENABLE ═══
# On Hyper-V VMs (systemd-detect-virt = "microsoft"), xRDP must be configured
# for vsock transport BEFORE GDM starts. cloudws-init handles runtime setup,
# but we also need a pre-GDM oneshot to ensure the first boot gets Enhanced Session.
cat > /usr/lib/systemd/system/cloudws-hyperv-enhanced.service <<'EOSVC'
[Unit]
Description=CloudWS Hyper-V Enhanced Session Setup
After=local-fs.target network.target
Before=gdm.service display-manager.service
ConditionVirtualization=microsoft

[Service]
Type=oneshot
ExecStart=/usr/libexec/cloudws-hyperv-enhanced
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOSVC

cat > /usr/libexec/cloudws-hyperv-enhanced <<'EOHV'
#!/bin/bash
set -euo pipefail
# Only configure if xRDP is installed
if [ ! -f /etc/xrdp/xrdp.ini ]; then
    echo "[cloudws-hyperv] xrdp not installed, skipping"
    exit 0
fi

echo "[cloudws-hyperv] Configuring Enhanced Session (vsock)..."

# Enable vsock transport for Hyper-V
sed -i 's/^use_vsock=.*/use_vsock=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^bitmap_compression=.*/bitmap_compression=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true

# Ensure xrdp services are running
systemctl enable --now xrdp xrdp-sesman 2>/dev/null || true

echo "[cloudws-hyperv] Enhanced Session ready"
EOHV
chmod +x /usr/libexec/cloudws-hyperv-enhanced
systemctl enable cloudws-hyperv-enhanced.service 2>/dev/null || true

# ═══ 15c. FIX COCKPIT SOCKET DROP-IN PERMISSIONS ═══
# Container builds sometimes leave listen.conf executable + world-writable.
# systemd warns about this on every boot.
if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    chmod 644 /etc/systemd/system/cockpit.socket.d/listen.conf
fi

# ═══ 15d. POLKIT CONTAINER WORKAROUND ═══
# polkit fails in rootless containers (needs CAP_SYS_ADMIN for namespace setup).
# This is expected in WSL2/Podman containers — not a bug on bare metal or Hyper-V VMs.
# Create a drop-in to reduce restart spam in container environments.
mkdir -p /usr/lib/systemd/system/polkit.service.d
cat > /usr/lib/systemd/system/polkit.service.d/10-cloudws-container.conf <<'DROPIN'
[Unit]
# CloudWS: Reduce restart spam when polkit can't get CAP_SYS_ADMIN in containers
StartLimitIntervalSec=300
StartLimitBurst=3

[Service]
Restart=on-failure
RestartSec=30
DROPIN

# ═══ 16. SELINUX BUILD-TIME FIXES ═══
# 16a. Restorecon — fix labels for all major trees
if command -v restorecon &>/dev/null; then
    restorecon -R /boot /etc /usr /var 2>/dev/null || true
fi

# 16b. Semanage import — atomic booleans + fcontexts (no ((var++)) under set -e)
if command -v semanage &>/dev/null; then
    echo "[99-overrides] Applying SELinux booleans and fcontexts via semanage import..."
    semanage import <<'EOSEM' 2>/dev/null || true
boolean -m --on daemons_dump_core
boolean -m --on domain_can_mmap_files
boolean -m --on virt_sandbox_use_all_caps
boolean -m --on virt_use_nfs
boolean -m --on nis_enabled
fcontext -a -t boot_t '/boot/bootupd-state.json'
fcontext -a -t accountsd_var_lib_t '/usr/share/accountsservice/interfaces(/.*)?'
fcontext -a -t ceph_var_lib_t '/var/lib/ceph(/.*)?'
fcontext -a -t ceph_log_t '/var/log/ceph(/.*)?'
EOSEM
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
    echo "[99-overrides] SELinux booleans and fcontexts applied"
fi

# 16c. Custom policy modules for known Fedora Rawhide denials
# CRITICAL: Use var=$((var + 1)) NOT ((var++)) — the latter returns exit code 1
# when the previous value is 0 under set -euo pipefail, killing the entire script.
if command -v checkmodule &>/dev/null && command -v semodule_package &>/dev/null; then
    echo "[99-overrides] Building custom SELinux policy modules..."

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
require { type fapolicyd_t; type xdm_t; class sock_file write; }
allow fapolicyd_t xdm_t:sock_file write;'

    CLOUDWS_POLICIES[chcon]='
module cloudws_chcon 1.0;
require { type chcon_t; class capability mac_admin; }
allow chcon_t self:capability mac_admin;'

    for name in "${!CLOUDWS_POLICIES[@]}"; do
        echo "${CLOUDWS_POLICIES[$name]}" > "/tmp/cloudws_${name}.te"
        if checkmodule -M -m -o "/tmp/cloudws_${name}.mod" "/tmp/cloudws_${name}.te" 2>/dev/null && \
           semodule_package -o "/tmp/cloudws_${name}.pp" -m "/tmp/cloudws_${name}.mod" 2>/dev/null && \
           semodule -i "/tmp/cloudws_${name}.pp" 2>/dev/null; then
            SELINUX_OK=$((SELINUX_OK + 1))
        else
            SELINUX_FAIL=$((SELINUX_FAIL + 1))
        fi
        rm -f "/tmp/cloudws_${name}".{te,mod,pp}
    done

    echo "[99-overrides] SELinux: ${SELINUX_OK} policies installed, ${SELINUX_FAIL} skipped (missing types in Rawhide policy)"
fi

# ═══ 16b. MASK SERIAL CONSOLE IN VMs ═══
# serial-getty@ttyS0 crash-loops in Hyper-V (no serial port) — noisy but harmless.
# Mask it everywhere (bare metal can unmask if serial console is needed).
systemctl mask serial-getty@ttyS0.service 2>/dev/null || true

# ═══ 17. SKELETON AUTOSTART ═══
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/cloudws-user-setup.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=CloudWS User Setup
Exec=bash -c "sleep 8 && flatpak install -y flathub-beta com.usebottles.bottles 2>/dev/null; rm -f ~/.config/autostart/cloudws-user-setup.desktop"
Hidden=false
X-GNOME-Autostart-enabled=true
DESK

echo "[99-overrides] CloudWS v1.2 fully configured."
