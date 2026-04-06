#!/bin/bash
# CloudWS v1.3 — 99-overrides: System configuration, tools, SELinux, VM gating
# This is the final build script. Everything here runs after packages are installed
# and services are enabled. It configures the user environment, injects tools,
# applies SELinux fixes, and gates services by virtualization type.
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════"
echo "  CloudWS v1.3 — System Overrides"
echo "═══════════════════════════════════════════════════════════════════"

# ═══ 0. PAM FIX ═══
echo "[99-overrides] Configuring PAM via authselect..."
if command -v authselect &>/dev/null; then
    authselect select local --force 2>/dev/null || {
        echo "[99-overrides] WARNING: authselect failed — applying manual pam_unix fallback"
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

# ═══ 1. USER CREATION ═══
echo "[99-overrides] Creating user INJ_U..."
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
echo "INJ_U:INJ_P" | chpasswd
echo "root:INJ_P" | chpasswd
passwd -u INJ_U 2>/dev/null || true

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

# ═══ 4. CLI ENVIRONMENT ═══
cat > /etc/profile.d/cloudws.sh <<'EOPROF'
cloudws() {
    echo ""
    echo "  Cloud Workstation OS v1.3"
    echo "  ════════════════════════════"
    echo "  cloudws-update          Check for OCI updates"
    echo "  cloudws-rebuild         Full rebuild from source"
    echo "  cloudws-build           Local container build"
    echo "  cloudws-backup          Backup /etc + /var/home"
    echo "  cloudws-deploy          Push to GHCR"
    echo "  cloudws-vfio-toggle     Bind/unbind GPU to VFIO"
    echo "  cloudws-hostname [name] View or set hostname"
    echo "  cloudws-k3s-join        Show K3s join command"
    echo "  cloudws-ceph            Ceph status/bootstrap/dashboard"
    echo "  cloudws-db              Database management (MariaDB/PostgreSQL/Redis)"
    echo "  cloudws-toggle-headless Toggle GUI on/off"
    echo "  cloudws-test            System health check"
    echo ""
    echo "  AI Stack (post-install):"
    echo "  cloudws-ai-intel        Intel oneAPI + OpenVINO + NPU"
    echo "  cloudws-ai-amd          AMD ROCm full stack + XDNA NPU"
    echo "  cloudws-ai-nvidia       NVIDIA CUDA + cuDNN + NCCL + TensorRT"
    echo "  cloudws-ai-full         Auto-detect + install all present AI hardware"
    echo ""
    echo "  iommu-groups            Show IOMMU groups"
    echo ""
}
alias scan-malware='podman run --rm -v /:/scan:ro docker.io/clamav/clamav:latest clamscan -r /scan --max-filesize=100M --max-scansize=500M 2>/dev/null'
if command -v fastfetch &>/dev/null; then fastfetch 2>/dev/null; fi
EOPROF

# Also inject fastfetch into .bashrc (Ptyxis uses non-login interactive shells)
# profile.d only runs on login shells — .bashrc is what Ptyxis sources.
if [ -f /etc/skel/.bashrc ]; then
    if ! grep -q 'fastfetch' /etc/skel/.bashrc; then
        cat >> /etc/skel/.bashrc <<'EOBASHRC'

# CloudWS: Show system info on terminal open
if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
    fastfetch 2>/dev/null
fi
EOBASHRC
    fi
else
    cat > /etc/skel/.bashrc <<'EOBASHRC'
# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# CloudWS: Show system info on terminal open
if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
    fastfetch 2>/dev/null
fi
EOBASHRC
fi

# ═══ 5. LOCALE ═══
echo "LANG=en_US.UTF-8" > /etc/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# ═══ 6. DYNAMIC HOSTNAME SERVICE ═══
cat > /usr/lib/systemd/system/cloudws-hostname.service <<'EOSVC'
[Unit]
Description=CloudWS Dynamic Hostname
After=local-fs.target
Before=network-pre.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'ID=$(head -c6 /etc/machine-id); hostnamectl set-hostname "CloudWS-${ID}" 2>/dev/null || true'
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOSVC
systemctl enable cloudws-hostname.service

# ═══ 7. CLOUD-INIT DEFAULTS ═══
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-cloudws.cfg <<'EOCLOUD'
preserve_hostname: false
ssh_pwauth: true
system_info:
  default_user:
    name: cloudws
    groups: [wheel, libvirt, kvm, video, render]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
datasource_list: [NoCloud, ConfigDrive, Azure, GCE, Ec2, None]
EOCLOUD

# ═══ 8. MULTIPATH DEFAULTS ═══
mkdir -p /etc/multipath
cat > /etc/multipath.conf <<'EOMP'
defaults {
    user_friendly_names yes
    find_multipaths yes
}
EOMP

# ═══ 9. FIREWALL CONFIGURATION ═══
cat > /usr/libexec/cloudws-firewall-init <<'EOFW'
#!/bin/bash
set -euo pipefail
if ! command -v firewall-cmd &>/dev/null; then
    echo "[cloudws-firewall] firewall-cmd not found — skipping"
    exit 0
fi
if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "[cloudws-firewall] firewalld not active — skipping"
    exit 0
fi

firewall-cmd --set-default-zone=drop 2>/dev/null || true

# Open services
for svc in cockpit ssh mdns; do
    firewall-cmd --permanent --add-service="$svc" 2>/dev/null || true
done

# Open ports
for port in \
    3389/tcp 3390/tcp \
    137-139/tcp 445/tcp \
    2049/tcp 111/tcp 111/udp 20048/tcp 20048/udp \
    16509/tcp \
    5900-5999/tcp \
    6443/tcp 10250/tcp \
    2224/tcp \
    5403-5405/udp \
    26000/tcp \
    8443/tcp \
    3306/tcp 5432/tcp 6379/tcp \
; do
    firewall-cmd --permanent --add-port="$port" 2>/dev/null || true
done

# Trust internal interfaces
for iface in lo podman0 virbr0 cni0 flannel.1 waydroid0; do
    firewall-cmd --permanent --zone=trusted --add-interface="$iface" 2>/dev/null || true
done

firewall-cmd --reload 2>/dev/null || true
echo "[cloudws-firewall] Firewall configured"
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
        uid=$(id -u "$u"); gid=$(id -g "$u")
        chown -R "${uid}:${gid}" "$home"
    fi
done

# Ensure groups are correct
for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
    for g in wheel libvirt kvm video render input dialout; do
        usermod -aG "$g" "$u" 2>/dev/null || true
    done
done

# Firewall init (only if firewalld active)
/usr/libexec/cloudws-firewall-init 2>/dev/null || true

# CrowdSec registration (only on bare metal)
VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
if [ "$VIRT" = "none" ] && command -v cscli &>/dev/null; then
    cscli hub update 2>/dev/null || true
    cscli collections install crowdsecurity/linux 2>/dev/null || true
fi

# PCP restart (ensures metrics collection)
systemctl restart pmproxy.service 2>/dev/null || true

# Flatpak dark theme
# CRITICAL: Do NOT use GTK_THEME=Adwaita-dark — it breaks libadwaita apps
# (shows old GTK3 look on GTK4/libadwaita apps like Nautilus, Settings, etc.)
# ADW_DEBUG_COLOR_SCHEME is the ONLY correct way to force dark mode globally.
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true
flatpak override --system --env=GTK_THEME= 2>/dev/null || true

# Hyper-V Enhanced Session auto-enable
if [ "$VIRT" = "microsoft" ] && [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    /usr/libexec/cloudws-hyperv-enhanced 2>/dev/null || true
fi

# bootc status
bootc status 2>/dev/null || true

echo "[cloudws-init] System initialized"
EOINIT
chmod +x /usr/libexec/cloudws-init
systemctl enable cloudws-init.service

# ═══ 12. CLOUDWS TOOLS ═══
echo "[99-overrides] Installing CloudWS tools..."

# cloudws-update
cat > /usr/bin/cloudws-update <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS — Checking for updates..."
ORIGIN=$(bootc status 2>/dev/null | grep -i "image:" | head -1 | awk '{print $NF}' || echo "")
if echo "$ORIGIN" | grep -q "localhost"; then
    echo "WARNING: Update origin is localhost — fixing to GHCR..."
    sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest
else
    sudo bootc upgrade
fi
EOTOOL

# cloudws-rebuild
cat > /usr/bin/cloudws-rebuild <<'EOTOOL'
#!/bin/bash
set -euo pipefail
DIR="${CLOUDWS_DIR:-$HOME/CloudWS-bootc}"
echo "CloudWS — Rebuilding from source..."
if [ ! -d "$DIR" ]; then
    git clone https://github.com/Kabuki94/CloudWS-bootc.git "$DIR"
else
    cd "$DIR" && git pull
fi
cd "$DIR"
if command -v just &>/dev/null; then
    just all
else
    podman build --squash-all --no-cache -t localhost/cloudws:latest .
    podman push localhost/cloudws:latest ghcr.io/kabuki94/cloudws-bootc:latest
fi
EOTOOL

# cloudws-build
cat > /usr/bin/cloudws-build <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS — Local build..."
podman build --squash-all --no-cache -t localhost/cloudws:latest .
EOTOOL

# cloudws-backup
cat > /usr/bin/cloudws-backup <<'EOTOOL'
#!/bin/bash
set -euo pipefail
DEST="${1:-/var/home/cloudws-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
echo "CloudWS — Backing up /etc and /var/home to $DEST..."
sudo tar czf "$DEST" /etc /var/home --exclude='/var/home/*/Downloads' --exclude='/var/home/*/.cache' 2>/dev/null
echo "Backup saved: $DEST ($(du -h "$DEST" | cut -f1))"
EOTOOL

# cloudws-deploy
cat > /usr/bin/cloudws-deploy <<'EOTOOL'
#!/bin/bash
set -euo pipefail
REGISTRY="${1:-ghcr.io/kabuki94/cloudws-bootc:latest}"
echo "CloudWS — Pushing to $REGISTRY..."
podman push localhost/cloudws:latest "$REGISTRY"
echo "Pushed to: $REGISTRY"
EOTOOL

# cloudws-vfio-toggle
cat > /usr/bin/cloudws-vfio-toggle <<'EOTOOL'
#!/bin/bash
set -euo pipefail
if [ -z "${1:-}" ]; then
    echo "Usage: cloudws-vfio-toggle <PCI_ADDR> [bind|unbind]"
    echo "Example: cloudws-vfio-toggle 0000:01:00.0 bind"
    exit 1
fi
PCI="$1"; ACTION="${2:-bind}"
if [ "$ACTION" = "bind" ]; then
    sudo driverctl set-override "$PCI" vfio-pci
    echo "Bound $PCI to vfio-pci"
else
    sudo driverctl unset-override "$PCI"
    echo "Unbound $PCI from vfio-pci"
fi
EOTOOL

# cloudws-hostname
cat > /usr/bin/cloudws-hostname <<'EOTOOL'
#!/bin/bash
set -euo pipefail
if [ -n "${1:-}" ]; then
    sudo hostnamectl set-hostname "$1"
    echo "Hostname set to: $1"
else
    echo "Hostname: $(hostname)"
    echo "Machine ID: $(cat /etc/machine-id)"
fi
EOTOOL

# iommu-groups
cat > /usr/bin/iommu-groups <<'EOTOOL'
#!/bin/bash
for g in $(find /sys/kernel/iommu_groups -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -t/ -k6 -n); do
    echo "IOMMU Group $(basename "$g"):"
    for d in "$g"/devices/*; do
        echo "  $(basename "$d") $(lspci -nns "$(basename "$d")" 2>/dev/null)"
    done
done
EOTOOL

# cloudws-k3s-join
cat > /usr/bin/cloudws-k3s-join <<'EOTOOL'
#!/bin/bash
set -euo pipefail
TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
if [ -f "$TOKEN_FILE" ]; then
    echo "K3s Join Token:"
    sudo cat "$TOKEN_FILE"
    echo ""
    IP=$(hostname -I | awk '{print $1}')
    echo "Join command for agents:"
    echo "  curl -sfL https://get.k3s.io | K3S_URL=https://${IP}:6443 K3S_TOKEN=<token> sh -"
else
    echo "K3s server not running or token not found."
    echo "Start K3s: sudo systemctl start k3s"
fi
EOTOOL

# cloudws-ceph
cat > /usr/bin/cloudws-ceph <<'EOTOOL'
#!/bin/bash
set -euo pipefail
case "${1:-status}" in
    status)    sudo ceph -s 2>/dev/null || echo "Ceph not initialized. Run: cloudws-ceph bootstrap" ;;
    dashboard) echo "Ceph Dashboard: https://$(hostname -I | awk '{print $1}'):8443" ;;
    bootstrap) echo "Bootstrapping Ceph..."; sudo cephadm bootstrap --mon-ip "$(hostname -I | awk '{print $1}')" --cluster-network "$(hostname -I | awk '{print $1}')/24" --allow-fqdn-hostname --single-host-defaults 2>&1 ;;
    *) echo "Usage: cloudws-ceph [status|dashboard|bootstrap]" ;;
esac
EOTOOL

# cloudws-db — Database management (MariaDB + PostgreSQL + Redis)
cat > /usr/bin/cloudws-db <<'EOTOOL'
#!/bin/bash
set -euo pipefail

usage() {
    echo ""
    echo "  CloudWS Database Manager"
    echo "  ════════════════════════"
    echo "  cloudws-db start [all|mariadb|postgresql|redis]"
    echo "  cloudws-db stop  [all|mariadb|postgresql|redis]"
    echo "  cloudws-db status"
    echo "  cloudws-db init-pgvector <dbname>   Create DB with pgvector extension"
    echo "  cloudws-db secure-mariadb           Run mysql_secure_installation"
    echo ""
}

case "${1:-}" in
    start)
        TARGET="${2:-all}"
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "mariadb" ]; then
            sudo systemctl start mariadb.service && echo "MariaDB started" || echo "MariaDB failed to start"
        fi
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "postgresql" ]; then
            sudo systemctl start postgresql.service && echo "PostgreSQL started" || echo "PostgreSQL failed to start"
        fi
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "redis" ]; then
            sudo systemctl start redis.service && echo "Redis started" || echo "Redis failed to start"
        fi
        ;;
    stop)
        TARGET="${2:-all}"
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "mariadb" ]; then
            sudo systemctl stop mariadb.service 2>/dev/null && echo "MariaDB stopped"
        fi
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "postgresql" ]; then
            sudo systemctl stop postgresql.service 2>/dev/null && echo "PostgreSQL stopped"
        fi
        if [ "$TARGET" = "all" ] || [ "$TARGET" = "redis" ]; then
            sudo systemctl stop redis.service 2>/dev/null && echo "Redis stopped"
        fi
        ;;
    status)
        echo "MariaDB:    $(systemctl is-active mariadb.service 2>/dev/null || echo 'not installed')"
        echo "PostgreSQL: $(systemctl is-active postgresql.service 2>/dev/null || echo 'not installed')"
        echo "Redis:      $(systemctl is-active redis.service 2>/dev/null || echo 'not installed')"
        echo ""
        if systemctl is-active --quiet mariadb.service 2>/dev/null; then
            echo "MariaDB version: $(mariadb --version 2>/dev/null | head -1)"
        fi
        if systemctl is-active --quiet postgresql.service 2>/dev/null; then
            echo "PostgreSQL version: $(psql --version 2>/dev/null | head -1)"
        fi
        ;;
    init-pgvector)
        DBNAME="${2:-}"
        if [ -z "$DBNAME" ]; then
            echo "Usage: cloudws-db init-pgvector <database_name>"
            exit 1
        fi
        echo "Creating database '$DBNAME' with pgvector extension..."
        sudo systemctl start postgresql.service 2>/dev/null || true
        sudo -u postgres createdb "$DBNAME" 2>/dev/null || echo "Database may already exist"
        sudo -u postgres psql -d "$DBNAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null
        echo "pgvector enabled on database: $DBNAME"
        echo "Connect: psql -U postgres -d $DBNAME"
        ;;
    secure-mariadb)
        echo "Running MariaDB secure installation..."
        sudo systemctl start mariadb.service 2>/dev/null || true
        sudo mariadb-secure-installation
        ;;
    *)
        usage
        ;;
esac
EOTOOL

# Cockpit desktop entry for dock pin
cat > /usr/share/applications/cockpit.desktop <<'EODT'
[Desktop Entry]
Type=Application
Name=Cockpit
Comment=Web-based server management
Exec=xdg-open https://localhost:9090
Icon=cockpit
Categories=System;
EODT

# Make all tools executable
chmod +x /usr/bin/cloudws-{update,rebuild,build,backup,deploy,vfio-toggle,hostname,k3s-join,ceph,db}
chmod +x /usr/bin/iommu-groups

# ═══ 12b. NEW v1.3 TOOLS: cloudws-toggle-headless + cloudws-test ═══
echo "[99-overrides] Installing cloudws-toggle-headless and cloudws-test..."
if [ -f /tmp/build/scripts/cloudws-toggle-headless ]; then
    cp /tmp/build/scripts/cloudws-toggle-headless /usr/bin/cloudws-toggle-headless
    chmod +x /usr/bin/cloudws-toggle-headless
    echo "[99-overrides] cloudws-toggle-headless installed"
fi
if [ -f /tmp/build/scripts/cloudws-test ]; then
    cp /tmp/build/scripts/cloudws-test /usr/bin/cloudws-test
    chmod +x /usr/bin/cloudws-test
    echo "[99-overrides] cloudws-test installed"
fi

# ═══ 12c. AI POST-INSTALL FRAMEWORK (Bazzite-style on-demand) ═══
echo "[99-overrides] Installing AI post-install commands..."
mkdir -p /usr/libexec/cloudws

# cloudws-ai-nvidia — CUDA + cuDNN + NCCL + TensorRT
cat > /usr/bin/cloudws-ai-nvidia <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "════════════════════════════════════════════════════════"
echo "  CloudWS AI Stack — NVIDIA (CUDA + cuDNN + NCCL + TensorRT)"
echo "════════════════════════════════════════════════════════"

# Check for NVIDIA GPU
if ! lspci | grep -qi nvidia; then
    echo "ERROR: No NVIDIA GPU detected. Aborting."
    exit 1
fi

echo "[1/4] Adding NVIDIA CUDA repository..."
sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/fedora39/x86_64/cuda-fedora39.repo 2>/dev/null || true

echo "[2/4] Installing CUDA Toolkit..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    cuda-toolkit \
    cuda-tools \
    cuda-compiler \
    cuda-libraries \
    cuda-cudart \
    cuda-nvcc \
    libcudnn9 \
    libcudnn9-devel \
    libnccl \
    libnccl-devel \
    2>/dev/null || true

echo "[3/4] Installing TensorRT..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    libnvinfer \
    libnvinfer-devel \
    python3-libnvinfer \
    2>/dev/null || true

echo "[4/4] Regenerating CDI spec..."
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.json 2>/dev/null || true

echo ""
echo "NVIDIA AI stack installed. Verify with:"
echo "  nvcc --version"
echo "  nvidia-smi"
echo "  python3 -c 'import torch; print(torch.cuda.is_available())'"
EOTOOL

# cloudws-ai-amd — ROCm full stack + XDNA NPU
cat > /usr/bin/cloudws-ai-amd <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "════════════════════════════════════════════════════════"
echo "  CloudWS AI Stack — AMD (ROCm + HIP + MIOpen + XDNA NPU)"
echo "════════════════════════════════════════════════════════"

# Check for AMD GPU
if ! lspci | grep -qi "amd.*vga\|radeon\|amd.*display"; then
    echo "WARNING: No AMD GPU detected. Installing ROCm CPU path only."
fi

echo "[1/4] Adding AMD ROCm repository..."
cat <<'EOROCM' | sudo tee /etc/yum.repos.d/rocm.repo > /dev/null
[ROCm-6.x]
name=ROCm 6.x
baseurl=https://repo.radeon.com/rocm/rhel9/6.4/main
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
EOROCM

echo "[2/4] Installing ROCm runtime + HIP..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    rocm-hip-runtime \
    rocm-hip-sdk \
    rocm-opencl-runtime \
    rocm-smi-lib \
    rocminfo \
    hip-runtime-amd \
    rocblas \
    rocsolver \
    rocfft \
    rocrand \
    miopen-hip \
    2>/dev/null || true

echo "[3/4] Installing AMD NPU drivers (XDNA)..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    xrt \
    xrt-devel \
    2>/dev/null || true

echo "[4/4] Setting up environment..."
cat <<'EOENV' | sudo tee /etc/profile.d/rocm.sh > /dev/null
export PATH=$PATH:/opt/rocm/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib:/opt/rocm/lib64
export HSA_OVERRIDE_GFX_VERSION=11.0.0
EOENV

echo ""
echo "AMD ROCm AI stack installed. Verify with:"
echo "  rocminfo"
echo "  rocm-smi"
echo "  python3 -c 'import torch; print(torch.hip.is_available())'"
EOTOOL

# cloudws-ai-intel — oneAPI + OpenVINO + NPU
cat > /usr/bin/cloudws-ai-intel <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "════════════════════════════════════════════════════════"
echo "  CloudWS AI Stack — Intel (oneAPI + OpenVINO + NPU)"
echo "════════════════════════════════════════════════════════"

echo "[1/5] Adding Intel oneAPI repository..."
cat <<'EOONEAPI' | sudo tee /etc/yum.repos.d/oneapi.repo > /dev/null
[oneAPI]
name=Intel oneAPI
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOONEAPI

echo "[2/5] Installing Intel oneAPI Base Toolkit (MKL, DPC++, TBB)..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    intel-oneapi-mkl \
    intel-oneapi-tbb \
    intel-oneapi-compiler-dpcpp-cpp \
    2>/dev/null || true

echo "[3/5] Installing OpenVINO runtime..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    openvino-runtime \
    openvino-runtime-cpu \
    openvino-runtime-gpu \
    openvino-runtime-npu \
    python3-openvino \
    2>/dev/null || true

echo "[4/5] Installing Intel GPU compute runtime (Level Zero)..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    intel-compute-runtime \
    level-zero \
    level-zero-devel \
    intel-opencl \
    intel-media-driver \
    2>/dev/null || true

echo "[5/5] Installing Intel NPU driver..."
sudo dnf install -y --skip-unavailable --allowerasing --nobest \
    intel-driver-compiler-npu \
    intel-level-zero-npu \
    2>/dev/null || true

echo ""
echo "Intel AI stack installed. Verify with:"
echo "  clinfo"
echo "  python3 -c 'from openvino import Core; print(Core().available_devices)'"
EOTOOL

# cloudws-ai-full — Auto-detect all present hardware and install all stacks
cat > /usr/bin/cloudws-ai-full <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "════════════════════════════════════════════════════════"
echo "  CloudWS AI Stack — Full Auto-Detect Install"
echo "════════════════════════════════════════════════════════"

INSTALLED=0

# Detect NVIDIA
if lspci | grep -qi nvidia; then
    echo ""
    echo ">>> NVIDIA GPU detected — installing CUDA stack..."
    cloudws-ai-nvidia
    INSTALLED=$((INSTALLED + 1))
fi

# Detect AMD
if lspci | grep -qiE "amd.*vga|radeon|amd.*display"; then
    echo ""
    echo ">>> AMD GPU detected — installing ROCm stack..."
    cloudws-ai-amd
    INSTALLED=$((INSTALLED + 1))
fi

# Detect Intel (GPU or NPU)
if lspci | grep -qiE "intel.*(vga|display|graphics)" || [ -d /sys/class/accel ]; then
    echo ""
    echo ">>> Intel GPU/NPU detected — installing oneAPI + OpenVINO..."
    cloudws-ai-intel
    INSTALLED=$((INSTALLED + 1))
fi

# Always install Intel for CPU path (MKL benefits all CPUs)
if [ $INSTALLED -eq 0 ]; then
    echo ""
    echo ">>> No discrete AI hardware detected — installing Intel oneAPI for CPU compute..."
    cloudws-ai-intel
    INSTALLED=1
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  AI stack installation complete ($INSTALLED stacks)"
echo "════════════════════════════════════════════════════════"

# Install common ML Python packages
echo ""
echo "Installing common ML Python packages..."
pip3 install --user --break-system-packages \
    numpy scipy scikit-learn pandas \
    onnxruntime \
    2>/dev/null || true

echo ""
echo "Common ML packages installed. For PyTorch/TensorFlow:"
echo "  NVIDIA: pip3 install torch torchvision torchaudio"
echo "  AMD:    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2"
echo "  Intel:  pip3 install intel-extension-for-pytorch"
EOTOOL

chmod +x /usr/bin/cloudws-ai-{nvidia,amd,intel,full}

# ═══ 13. DESKTOP BLOAT CLEANUP ═══
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

# ═══ 15. VM-SPECIFIC SERVICE GATING ═══
# 15a. GDM: only skip in WSL2 (Hyper-V VMs SHOULD run GDM)
mkdir -p /usr/lib/systemd/system/gdm.service.d
cat > /usr/lib/systemd/system/gdm.service.d/10-skip-wsl.conf <<'DROPIN'
[Unit]
# CloudWS: Skip GDM in WSL2 — WSLg provides display server
# Hyper-V VMs still get GDM (they have hyperv_drm framebuffer)
ConditionPathExists=!/proc/sys/fs/binfmt_misc/WSLInterop
DROPIN

# 15b. nvidia-powerd: skip in ALL VMs (no physical NVIDIA GPU)
if [ -f /usr/lib/systemd/system/nvidia-powerd.service ]; then
    mkdir -p /usr/lib/systemd/system/nvidia-powerd.service.d
    cat > /usr/lib/systemd/system/nvidia-powerd.service.d/10-bare-metal-only.conf <<'DROPIN'
[Unit]
ConditionVirtualization=no
DROPIN
fi

# 15c. WSL2-specific masks (in addition to 20-services.sh drop-ins)
# These are belts-and-suspenders for services that MUST NOT run in WSL2
cat > /usr/libexec/cloudws-wsl-mask <<'EOWSL'
#!/bin/bash
# Called at boot in WSL2 only (ConditionPathExists=/proc/sys/fs/binfmt_misc/WSLInterop)
for svc in gdm firewalld waydroid-container nvidia-powerd crowdsec crowdsec-firewall-bouncer dev-binderfs.mount; do
    systemctl mask "$svc" 2>/dev/null || true
done
EOWSL
chmod +x /usr/libexec/cloudws-wsl-mask

# 15d. Container/VM nvidia block (not WSL specific — any VM)
# nvidia-powerd bare-metal-only handled above

# 15e. FIX COCKPIT SOCKET DROP-IN PERMISSIONS ═══
if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    chmod 644 /etc/systemd/system/cockpit.socket.d/listen.conf
fi

# 15f. POLKIT CONTAINER WORKAROUND ═══
mkdir -p /usr/lib/systemd/system/polkit.service.d
cat > /usr/lib/systemd/system/polkit.service.d/10-cloudws-container.conf <<'DROPIN'
[Unit]
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

# 16b. Semanage import — atomic booleans + fcontexts
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
fcontext -a -t mysqld_db_t '/var/lib/mysql(/.*)?'
fcontext -a -t postgresql_db_t '/var/lib/pgsql(/.*)?'
EOSEM
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
    restorecon -R /var/lib/mysql 2>/dev/null || true
    restorecon -R /var/lib/pgsql 2>/dev/null || true
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

    for name in "${!CLOUDWS_POLICIES[@]}"; do
        echo "${CLOUDWS_POLICIES[$name]}" > "/tmp/cloudws_${name}.te"
        if checkmodule -M -m -o "/tmp/cloudws_${name}.mod" "/tmp/cloudws_${name}.te" 2>/dev/null && \
           semodule_package -o "/tmp/cloudws_${name}.pp" -m "/tmp/cloudws_${name}.mod" 2>/dev/null && \
           semodule -i "/tmp/cloudws_${name}.pp" 2>/dev/null; then
            echo "[99-overrides] SELinux module cloudws_${name}: OK"
            SELINUX_OK=$((SELINUX_OK + 1))
        else
            echo "[99-overrides] SELinux module cloudws_${name}: SKIPPED (type missing in Rawhide policy)"
            SELINUX_FAIL=$((SELINUX_FAIL + 1))
        fi
        rm -f "/tmp/cloudws_${name}".{te,mod,pp}
    done

    echo "[99-overrides] SELinux: ${SELINUX_OK} policies installed, ${SELINUX_FAIL} skipped (missing types in Rawhide policy)"
fi

# ═══ 16d. MASK SERIAL CONSOLE IN VMs ═══
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

echo "[99-overrides] CloudWS v1.3 fully configured."
