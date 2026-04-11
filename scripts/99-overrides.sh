#!/bin/bash
# CloudWS v1.4 — 99-overrides: System configuration, tools, SELinux, VM gating
# This is the final build script. Everything here runs after packages are installed
# and services are enabled. It configures the user environment, injects tools,
# applies SELinux fixes, and gates services by virtualization type.
#
# CHANGELOG v1.4:
#   - SECURITY: INJ_P → INJ_HASH — password is now a SHA-512 hash ($6$...)
#   - SECURITY: chpasswd → chpasswd -e — accepts pre-hashed passwords
#   - Plaintext password NEVER appears in build logs
#
# CHANGELOG v1.3:
#   - RTX 50-series VFIO reset bug detection + warning in GPU detect
#   - cloudws-update: tag-aware upgrade support (bootc v1.15+)
#   - New tool: cloudws-vfio-check (validates passthrough readiness)
#   - New SELinux policies for systemd 260 (homed, portabled)
#   - Updated MOTD/banner to v1.3
#   - composefs status check in cloudws-init
#   - /opt → /var/opt auto-creation in init
set -euo pipefail

echo "═══════════════════════════════════════════════════════════════════"
echo "  CloudWS v1.4 — System Overrides"
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

# ═══ 1. CLI ENVIRONMENT (must come BEFORE useradd -m so skel is populated) ═══
cat >> /etc/skel/.bashrc <<'EOBASH'

# ── CloudWS v1.4 ──────────────────────────────────────────────────
cloudws() {
    echo ""
    echo "  CloudWS v1.4 — Cloud Workstation OS"
    echo "  ─────────────────────────────────────"
    echo "  cloudws-update        Check for & apply OS updates"
    echo "  cloudws-rebuild       Build from source + push to GHCR"
    echo "  cloudws-build         Local OCI build only"
    echo "  cloudws-backup        Snapshot /etc + /var/home"
    echo "  cloudws-deploy        Deploy image to bare metal"
    echo "  cloudws-vfio-toggle   Bind/unbind GPU from vfio-pci"
    echo "  cloudws-vfio-check    Validate VFIO passthrough readiness"
    echo "  cloudws-hostname      Set unique HA hostname"
    echo "  cloudws-test          Run system health checks"
    echo "  cloudws-toggle-headless  Switch desktop/headless mode"
    echo "  iommu-groups          List IOMMU groups"
    echo "  scan-malware          ClamAV container scan"
    echo ""
}
alias scan-malware='podman run --rm -v /:/scan:ro docker.io/clamav/clamav:latest clamscan -r /scan/home --max-filesize=100M --max-scansize=500M 2>/dev/null'

# Fastfetch on terminal open (interactive only)
if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
    fastfetch --logo none --color blue 2>/dev/null || true
fi
EOBASH

# ═══ 2. USER CREATION ═══
# Password is pre-hashed (SHA-512) by the orchestrator — plaintext NEVER in build log.
# The orchestrator replaces INJ_HASH with a $6$salt$hash string before podman build.
echo "[99-overrides] Creating user INJ_U..."
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
echo "INJ_U:INJ_HASH" | chpasswd -e
echo "root:INJ_HASH" | chpasswd -e
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
# (skel .bashrc already written above before useradd)

# ═══ 5. LOCALE ═══
echo "LANG=en_US.UTF-8" > /etc/locale.conf
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# ═══ 5b. GTK/QT THEMING — MODERN LOOK EVERYWHERE ═══
echo "[99-overrides] Configuring unified dark theme for all toolkits..."

# GTK3: adw-gtk3-dark makes GTK3 apps match libadwaita's modern look
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<'EOGTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Geist 11
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=:minimize,maximize,close
EOGTK3

# GTK4: libadwaita apps use color-scheme (NOT GTK_THEME)
mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/settings.ini <<'EOGTK4'
[Settings]
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Geist 11
gtk-decoration-layout=:minimize,maximize,close
EOGTK4

# System-wide env vars for ALL toolkits (GTK3, GTK4/libadwaita, Qt5/6, Electron)
mkdir -p /etc/environment.d
cat > /etc/environment.d/70-cloudws-theme.conf <<'EOENV'
# CloudWS v1.4: Unified dark theme for ALL window toolkits
# GTK3 apps (Cockpit webview, Wine dialogs, older GNOME apps)
GTK_THEME=adw-gtk3-dark
# libadwaita apps (GNOME 40+ native apps) — do NOT use GTK_THEME for these
ADW_DEBUG_COLOR_SCHEME=prefer-dark
# Qt5/Qt6 apps
QT_QPA_PLATFORMTHEME=adwaita-dark
QT_STYLE_OVERRIDE=adwaita-dark
EOENV

# ═══ 6. HOSTNAME ═══
echo "CloudWS" > /etc/hostname

# ═══ 7. CLOUD-INIT ═══
mkdir -p /etc/cloud/cloud.cfg.d
cat > /etc/cloud/cloud.cfg.d/99-cloudws.cfg <<'EOCI'
preserve_hostname: false
ssh_pwauth: true
system_info:
  default_user:
    name: INJ_U
    lock_passwd: false
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel, libvirt, kvm, video, render
datasource_list: [NoCloud, None, Azure, GCE, Ec2, Openstack]
EOCI

# ═══ 8. MULTIPATH ═══
mkdir -p /etc/multipath
cat > /etc/multipath.conf <<'EOMP'
defaults {
    user_friendly_names yes
    find_multipaths yes
}
EOMP

# ═══ 9. FIREWALL ═══
cat > /usr/libexec/cloudws-firewall-init <<'EOFW'
#!/bin/bash
set -euo pipefail
# Guard: only run if firewalld is active
if ! systemctl is-active --quiet firewalld 2>/dev/null; then
    echo "[cloudws-firewall] firewalld not active — skipping"
    exit 0
fi
# Default zone: drop (deny all inbound by default)
firewall-cmd --set-default-zone=drop 2>/dev/null || true
# Open essential services
for svc in cockpit ssh mdns; do
    firewall-cmd --permanent --add-service="$svc" 2>/dev/null || true
done
# RDP (xRDP standard + Hyper-V vsock)
firewall-cmd --permanent --add-port=3389/tcp --add-port=3390/tcp 2>/dev/null || true
# Samba
firewall-cmd --permanent --add-service=samba 2>/dev/null || true
# NFS
firewall-cmd --permanent --add-service=nfs --add-service=rpc-bind --add-service=mountd 2>/dev/null || true
# Libvirt
firewall-cmd --permanent --add-port=16509/tcp 2>/dev/null || true
# VNC
firewall-cmd --permanent --add-port=5900-5999/tcp 2>/dev/null || true
# K3s API + kubelet
firewall-cmd --permanent --add-port=6443/tcp --add-port=10250/tcp 2>/dev/null || true
# Pacemaker/Corosync
firewall-cmd --permanent --add-port=2224/tcp --add-port=5403-5405/udp 2>/dev/null || true
# CrowdSec dashboard
firewall-cmd --permanent --add-port=3000/tcp 2>/dev/null || true
# iVentoy
firewall-cmd --permanent --add-port=26000/tcp 2>/dev/null || true
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

    # v1.3: RTX 50-series (Blackwell) VFIO reset bug detection
    if command -v lspci &>/dev/null; then
        if lspci -nn | grep -iE '\[10de:(2900|2901|2903|2904|2905|2b80|2b85)\]' &>/dev/null; then
            echo "[cloudws-gpu-detect] WARNING: RTX 50-series GPU detected!"
            echo "[cloudws-gpu-detect] These GPUs have a known VFIO reset bug."
            echo "[cloudws-gpu-detect] VFIO passthrough may require full host reboot after VM shutdown."
            echo "[cloudws-gpu-detect] See: /usr/share/doc/cloudws-vfio-warning.txt"
            wall "CloudWS: RTX 50-series VFIO reset bug detected. See /usr/share/doc/cloudws-vfio-warning.txt" 2>/dev/null || true
        fi
    fi
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

# Ensure /var/opt exists (for /opt → /var/opt symlink)
mkdir -p /var/opt

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
flatpak override --system --env=ADW_DEBUG_COLOR_SCHEME=prefer-dark 2>/dev/null || true

# Hyper-V Enhanced Session auto-enable
if [ "$VIRT" = "microsoft" ] && [ ! -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    /usr/libexec/cloudws-hyperv-enhanced 2>/dev/null || true
fi

# bootc status
bootc status 2>/dev/null || true

echo "[cloudws-init] CloudWS v1.4 initialized"
EOINIT
chmod +x /usr/libexec/cloudws-init
systemctl enable cloudws-init.service

# ═══ 12. CLOUDWS TOOLS ═══
echo "[99-overrides] Installing CloudWS tools..."

# cloudws-update (v1.3: tag-aware upgrade support)
cat > /usr/bin/cloudws-update <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS v1.4 — Checking for updates..."
ORIGIN=$(bootc status 2>/dev/null | grep -i "image:" | head -1 | awk '{print $NF}' || echo "")
if echo "$ORIGIN" | grep -q "localhost"; then
    echo "WARNING: Update origin is localhost — switching to GHCR..."
    sudo bootc switch ghcr.io/kabuki94/cloudws-bootc:latest
else
    echo "Current image: $ORIGIN"
    sudo bootc upgrade
    echo ""
    echo "If an update was staged, reboot to apply: sudo reboot"
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
BACKUP_DIR="/var/lib/cloudws/backups"
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"
echo "CloudWS — Backing up system state..."
tar czf "$BACKUP_DIR/etc-${TS}.tar.gz" /etc/ 2>/dev/null || true
tar czf "$BACKUP_DIR/home-${TS}.tar.gz" /var/home/ 2>/dev/null || true
echo "Backups saved to $BACKUP_DIR/"
ls -lh "$BACKUP_DIR/"*"${TS}"*
EOTOOL

# cloudws-deploy
cat > /usr/bin/cloudws-deploy <<'EOTOOL'
#!/bin/bash
set -euo pipefail
IMAGE="${1:-ghcr.io/kabuki94/cloudws-bootc:latest}"
echo "CloudWS — Deploying $IMAGE to bare metal..."
echo "WARNING: This will overwrite the current system!"
read -rp "Continue? [y/N]: " confirm
if [[ "$confirm" =~ ^[Yy] ]]; then
    sudo bootc switch "$IMAGE"
    echo "Deploy staged. Reboot to apply: sudo reboot"
fi
EOTOOL

# cloudws-vfio-toggle
cat > /usr/bin/cloudws-vfio-toggle <<'EOTOOL'
#!/bin/bash
set -euo pipefail
if [ -z "${1:-}" ]; then
    echo "Usage: cloudws-vfio-toggle <PCI_SLOT> [bind|unbind]"
    echo "Example: cloudws-vfio-toggle 0000:01:00.0 bind"
    exit 1
fi
PCI="$1"
ACTION="${2:-bind}"
if [ "$ACTION" = "bind" ]; then
    echo "$PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    echo "Bound $PCI to vfio-pci"
else
    echo "$PCI" | sudo tee /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
    echo "Unbound $PCI from vfio-pci"
fi
EOTOOL

# cloudws-vfio-check (NEW v1.3)
cat > /usr/bin/cloudws-vfio-check <<'EOTOOL'
#!/bin/bash
set -euo pipefail
echo "CloudWS v1.4 — VFIO Passthrough Readiness Check"
echo "════════════════════════════════════════════════"
echo ""

# IOMMU
if dmesg 2>/dev/null | grep -qi "IOMMU enabled"; then
    echo "  ✓ IOMMU: Enabled"
else
    echo "  ✗ IOMMU: Not detected (add iommu=pt to kernel args)"
fi

# VFIO modules
for mod in vfio vfio_iommu_type1 vfio_pci; do
    if modprobe -n "$mod" 2>/dev/null; then
        echo "  ✓ Module: $mod available"
    else
        echo "  ✗ Module: $mod not available"
    fi
done

# NVIDIA GPUs
echo ""
echo "NVIDIA GPUs detected:"
lspci -nn | grep -i nvidia | while read -r line; do
    echo "  $line"
    # Check for RTX 50-series (Blackwell)
    if echo "$line" | grep -qiE '\[10de:(2900|2901|2903|2904|2905|2b80|2b85)\]'; then
        echo "    ⚠ WARNING: RTX 50-series — VFIO reset bug!"
        echo "    See: /usr/share/doc/cloudws-vfio-warning.txt"
    fi
done

# IOMMU groups
echo ""
echo "IOMMU Groups with NVIDIA:"
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    for d in "$g"/devices/*; do
        if lspci -nns "${d##*/}" 2>/dev/null | grep -qi nvidia; then
            echo "  Group ${g##*/}: $(lspci -nns "${d##*/}")"
        fi
    done
done
EOTOOL

# cloudws-hostname
cat > /usr/bin/cloudws-hostname <<'EOTOOL'
#!/bin/bash
set -euo pipefail
ID=$(cat /etc/machine-id | head -c6)
NEW="${1:-CloudWS-${ID}}"
sudo hostnamectl set-hostname "$NEW"
echo "Hostname set to: $NEW"
EOTOOL

# iommu-groups
cat > /usr/bin/iommu-groups <<'EOTOOL'
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo -e "\033[1;34mIOMMU Group ${g##*/}:\033[0m"
    for d in "$g"/devices/*; do
        echo "  $(lspci -nns "${d##*/}")"
    done
done
EOTOOL

# Make all tools executable
for tool in cloudws-update cloudws-rebuild cloudws-build cloudws-backup \
            cloudws-deploy cloudws-vfio-toggle cloudws-vfio-check \
            cloudws-hostname iommu-groups; do
    chmod +x "/usr/bin/$tool"
done

# Cockpit desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/cockpit.desktop <<'EODESKTOP'
[Desktop Entry]
Type=Application
Name=Cockpit
Comment=Server management web interface
Exec=xdg-open https://localhost:9090
Icon=cockpit
Categories=System;
EODESKTOP

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

# ═══ 13. DESKTOP BLOAT CLEANUP ═══
# REMOVED: User wants all apps visible. Apps are organized into dconf folders instead.

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

# 15c. Waydroid + binder: skip in WSL2 (no binder/ashmem)
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

# ═══ 15d. HYPER-V ENHANCED SESSION — FIRST-BOOT AUTO-ENABLE ═══
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
if [ ! -f /etc/xrdp/xrdp.ini ]; then
    echo "[cloudws-hyperv] xrdp not installed, skipping"
    exit 0
fi
echo "[cloudws-hyperv] Configuring Enhanced Session (vsock)..."
sed -i 's/^use_vsock=.*/use_vsock=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^crypt_level=.*/crypt_level=none/' /etc/xrdp/xrdp.ini 2>/dev/null || true
sed -i 's/^bitmap_compression=.*/bitmap_compression=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
systemctl enable --now xrdp xrdp-sesman 2>/dev/null || true
echo "[cloudws-hyperv] Enhanced Session ready"
EOHV
chmod +x /usr/libexec/cloudws-hyperv-enhanced
systemctl enable cloudws-hyperv-enhanced.service 2>/dev/null || true

# ═══ 15e. FIX COCKPIT SOCKET DROP-IN PERMISSIONS ═══
if [ -f /etc/systemd/system/cockpit.socket.d/listen.conf ]; then
    chmod 644 /etc/systemd/system/cockpit.socket.d/listen.conf
fi

# ═══ 15f. POLKIT CONTAINER WORKAROUND ═══
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
    echo "[99-overrides] Applying SELinux booleans and fcontexts..."
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

    # NEW v1.3: accounts-daemon watch on overlay — stops the #1 log spammer
    # AVC denied { watch } for comm="gmain" path="/usr/share/accountsservice/interfaces"
    CLOUDWS_POLICIES[accountsd_watch]='
module cloudws_accountsd_watch 1.0;
require { type accountsd_t; type usr_t; class dir { watch watch_reads }; }
allow accountsd_t usr_t:dir { watch watch_reads };'

    # NEW v1.3: fapolicyd → GDM userdb socket during trust DB updates
    CLOUDWS_POLICIES[fapolicyd_gdm]='
module cloudws_fapolicyd_gdm 1.0;
require { type fapolicyd_t; type xdm_t; class unix_stream_socket connectto; }
allow fapolicyd_t xdm_t:unix_stream_socket connectto;'

    # NEW v1.3: systemd-portabled for sysext/confext support (systemd 258+)
    CLOUDWS_POLICIES[portabled]='
module cloudws_portabled 1.0;
require { type init_t; type systemd_portabled_t; class dbus send_msg; }
allow init_t systemd_portabled_t:dbus send_msg;
allow systemd_portabled_t init_t:dbus send_msg;'

    # NEW v1.3: kvmfr — Looking Glass shared memory device
    CLOUDWS_POLICIES[kvmfr]='
module cloudws_kvmfr 1.0;
require { type svirt_t; type device_t; class chr_file { open read write map getattr }; }
allow svirt_t device_t:chr_file { open read write map getattr };'

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

    echo "[99-overrides] SELinux: ${SELINUX_OK} policies installed, ${SELINUX_FAIL} skipped"
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

echo "[99-overrides] CloudWS v1.4 fully configured."

# ═══ 17. GNOME REMOTE DESKTOP — BROWSER/REMOTE ACCESS ═══
echo "[99-overrides] Installing gnome-remote-desktop first-boot setup..."
cp /tmp/build/scripts/cloudws-grd-setup /usr/libexec/cloudws-grd-setup
chmod +x /usr/libexec/cloudws-grd-setup
systemctl enable cloudws-grd-setup.service 2>/dev/null || true

# ═══ 18. xRDP ENHANCED SESSION — FIX SESSION LAUNCH ═══
echo "[99-overrides] Fixing xRDP session launcher..."
if [ -d /etc/xrdp ]; then
    cat > /etc/xrdp/startwm.sh <<'EOXRDP'
#!/bin/sh
if [ -r /etc/profile ]; then . /etc/profile; fi
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export GNOME_SHELL_SESSION_MODE=gnome
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24
exec gnome-session
EOXRDP
    chmod +x /etc/xrdp/startwm.sh
    if [ -f /etc/xrdp/sesman.ini ]; then
        sed -i 's/^MaxSessions=.*/MaxSessions=10/' /etc/xrdp/sesman.ini 2>/dev/null || true
        sed -i 's/^KillDisconnected=.*/KillDisconnected=false/' /etc/xrdp/sesman.ini 2>/dev/null || true
    fi
fi

# ═══ 19. MOTD — SERVICE DASHBOARD WITH CLICKABLE LINKS ═══
echo "[99-overrides] Installing CloudWS MOTD dashboard..."
cp /tmp/build/scripts/cloudws-motd /usr/libexec/cloudws-motd
chmod +x /usr/libexec/cloudws-motd
echo "[99-overrides] Remote desktop + MOTD installed"
