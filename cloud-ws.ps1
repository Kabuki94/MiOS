<#
.SYNOPSIS
    Cloud-WS: Full Deployment Architecture (Fedora Rawhide 7.0 Edition)
.DESCRIPTION
    The definitive orchestrator for the Cloud-WS immutable operating system.
    Builds a hardware-optimized Fedora Rawhide OCI image with full GNOME 50+,
    dual-GPU support (AMD iGPU + NVIDIA dGPU), and exports to all target formats.

    Target Hardware  : AMD Ryzen 9 9950X3D (RDNA2 iGPU) + NVIDIA RTX 4090
    OS Architecture  : Fedora Rawhide | Native 7.0 Kernel | GNOME 50
    Deployment Core  : Native Fedora Bootc + ComposeFS + OSTree
    
    TARGET 1 : Bare Metal RAW Image      (cloudws-bootable.raw)
    TARGET 2 : Hyper-V Gen2 VHDX         (cloudws-hyperv.vhdx)
    TARGET 3 : WSL2 + WSLg Tarball       (cloudws-wsl.tar)
    TARGET 4 : Anaconda Installer ISO    (cloudws-installer.iso)
    TARGET 5 : GHCR Registry Push        (ghcr.io/kabuki94/cloudws-bootc:latest)

.NOTES
    v13.0.0 — Full-featured consolidation.
    - ADDED: CrowdSec IPS sovereign mode WITH acquisition config (journalctl datasource).
    - ADDED: Firewall default-deny drop zone + all service ports (RDP/Cockpit/SSH/Samba/NFS).
    - ADDED: GPU auto-detect service (blocks NVIDIA in VMs, enables virtual GPU).
    - ADDED: Looking Glass B7 (low-latency GPU passthrough display).
    - ADDED: xRDP with Hyper-V Enhanced Session (vsock transport).
    - ADDED: Waydroid (Android with GAPPS, native Wayland windows).
    - ADDED: K3s lightweight Kubernetes.
    - ADDED: HA clustering (Corosync/Pacemaker/PCS).
    - ADDED: fapolicyd + USBGuard security hardening.
    - ADDED: ZRAM swap, sysctl VM host tuning, environment variables.
    - ADDED: Gamescope SteamOS-mode GDM session.
    - ADDED: cloud-init autonomous deployment config.
    - ADDED: SELinux build-time fixes (bootupd, accountsd, homed).
    - ADDED: Cockpit listen on all interfaces + all Cockpit plugins.
    - ADDED: cloudws-rebuild, cloudws-vfio-toggle, scan-malware tools.
    - FIXED: CrowdSec "no datasource enabled" crash loop.
    - FIXED: cloudws-init runs every boot (not just first boot).
    - FIXED: Firewall opens RDP 3389/3390, Cockpit 9090, Samba, NFS, libvirt.
    - INCLUDES: cockpit-image-builder, osbuild-composer, AMD RDNA2 iGPU, NTSync.
    - INCLUDES: Cockpit Benchmark + ZFS Manager plugins from upstream git.
    - INCLUDES: Polkit passwordless wheel + libvirt rules.
    - INCLUDES: Indestructible /etc/group injection for Fedora NSS container desync.
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  ENGINE CONFIGURATION & TARGET SPECIFICATIONS
# ══════════════════════════════════════════════════════════════════════════════
$ImageName      = "cloudws"
$ImageTag       = "latest"
$U              = "cloudws"   # Default username (injected into scripts)
$P              = "cloudws"   # Default password (injected into scripts)
$LocalImage     = "localhost/${ImageName}:${ImageTag}"
$GhcrImage      = "ghcr.io/kabuki94/cloudws-bootc:latest"
$OutputFolder   = Join-Path $PWD "cloudws-deploy-out"
$B              = Join-Path $env:TEMP "cloudws-full-build"
$LogFile        = Join-Path $OutputFolder "build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

$RawImg         = Join-Path $OutputFolder "cloudws-bootable.raw"
$TargetVhdx     = Join-Path $OutputFolder "cloudws-hyperv.vhdx"
$TargetWsl      = Join-Path $OutputFolder "cloudws-wsl.tar"
$TargetIso      = Join-Path $OutputFolder "cloudws-installer.iso"

$RAW_DISK_GB    = 20
$MIN_FREE_GB    = 60

# ══════════════════════════════════════════════════════════════════════════════
#  UI & LOGGING ENGINE
# ══════════════════════════════════════════════════════════════════════════════
function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $w = 80
    $pad = [math]::Max(0, [math]::Floor(($w - $Text.Length - 4) / 2))
    $line = "═" * $w
    Write-Host "`n$line" -ForegroundColor $Color
    Write-Host ("║" + " " * $pad + " $Text " + " " * ($w - $pad - $Text.Length - 2) + "║") -ForegroundColor $Color
    Write-Host "$line`n" -ForegroundColor $Color
}

function Write-Phase {
    param([int]$Num, [string]$Label)
    Write-Host "`n  [$Num] $Label" -ForegroundColor Yellow
    Write-Host "  $("─" * 70)" -ForegroundColor DarkGray
}

function Write-Step  { param([string]$Msg) Write-Host "      » $Msg" -ForegroundColor DarkCyan }
function Write-OK    { param([string]$Msg) Write-Host "      ✓ $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "      ⚠ $Msg" -ForegroundColor Yellow }
function Write-Fatal {
    param([string]$Msg)
    Write-Host "`n  ✗ FATAL ERROR: $Msg" -ForegroundColor Red
    Write-Host ""
    exit 1
}

function Invoke-Cmd {
    param([string]$Desc, [scriptblock]$Block)
    Write-Step $Desc
    try {
        & $Block
        if ($LASTEXITCODE -ne 0) { throw "Command returned exit code $LASTEXITCODE" }
    } catch {
        Write-Fatal "$Desc failed: $_"
    }
}

function Get-FileSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "N/A" }
    $bytes = (Get-Item $Path).Length
    if ($bytes -gt 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -gt 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    return "{0:N0} KB" -f ($bytes / 1KB)
}

function Write-TargetReport {
    param([string]$Num, [string]$Label, [bool]$OK, [string]$Path, [string]$Usage)
    $icon  = if ($OK) { "✓" } else { "✗" }
    $color = if ($OK) { "Green" } else { "Red" }
    Write-Host "  [$icon] TARGET $Num — $Label" -ForegroundColor $color
    if ($OK) {
        Write-Host "      Path : $Path" -ForegroundColor White
        Write-Host "      Size : $(Get-FileSize $Path)" -ForegroundColor DarkGray
        Write-Host "      Use  : $Usage" -ForegroundColor DarkGray
    } else {
        Write-Host "      FAILED — Check build output above." -ForegroundColor DarkRed
    }
    Write-Host ""
}

function Assert-FreeDisk {
    param([int]$RequiredGB)
    $drive = (Get-Item $PWD).PSDrive.Name
    $freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
    if ($freeGB -lt $RequiredGB) {
        Write-Fatal "Insufficient disk space on ${drive}: (${freeGB} GB free, need ${RequiredGB} GB)."
    }
    Write-OK "Host Storage: ${freeGB} GB free on ${drive}:"
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0: PRE-FLIGHT & HARDWARE DISCOVERY
# ══════════════════════════════════════════════════════════════════════════════
Write-Banner "CLOUD-WS FEDORA RAWHIDE DEPLOYMENT v13.0.0"

Write-Host "  Target   : AMD Ryzen 9 9950X3D (RDNA2 iGPU) + NVIDIA RTX 4090" -ForegroundColor Gray
Write-Host "  Base     : Fedora Rawhide | Native 7.0 Kernel | GNOME 50" -ForegroundColor Gray
Write-Host "  Bootc    : ComposeFS + OSTree (immutable, atomic upgrades)" -ForegroundColor Gray
Write-Host "  Targets  : RAW → VHDX → WSL2 → ISO → GHCR" -ForegroundColor Gray

Write-Phase 0 "Hardware Assessment & Validation"

if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null }
Assert-FreeDisk $MIN_FREE_GB

try {
    $podmanVer = & podman --version 2>&1
    Write-OK "Container Engine: $podmanVer"
} catch { Write-Fatal "Podman is not installed or not in PATH." }

$wslCheck = & wsl --status 2>&1
if ($wslCheck -match "not installed" -or $LASTEXITCODE -ne 0) {
    Write-Warn "WSL2 may not be fully configured — continuing..."
} else {
    Write-OK "WSL2 subsystem present"
}

$cpuCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$ramMB = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
Write-OK "Processor : $cpuCount logical cores detected"
Write-OK "Memory    : $ramMB MB physical RAM"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1: PODMAN BACKEND INITIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 1 "Podman Machine — Allocating $cpuCount Threads / $ramMB MB RAM"

$ErrorActionPreference = "Continue"
Write-Step "Shutting down WSL for clean state..."
& wsl --shutdown 2>$null
Start-Sleep -Seconds 3

$vmStatus = & podman machine inspect podman-machine-default 2>&1
if ($LASTEXITCODE -ne 0 -or "$vmStatus" -match "does not exist|not found") {
    Write-Step "Initializing new rootful Podman machine (150 GB disk)..."
    & podman machine init --rootful --cpus $cpuCount --memory $ramMB --disk-size 150
} else {
    Write-Step "Reconfiguring existing machine for maximum resources..."
    & podman machine stop 2>$null
    Start-Sleep -Seconds 3
    & podman machine set --cpus $cpuCount --memory $ramMB 2>&1 | ForEach-Object {
        if ($_ -match "not supported") { Write-Warn $_ } else { Write-Host "        $_" -ForegroundColor DarkGray }
    }
}

& podman machine start
if ($LASTEXITCODE -ne 0) {
    Write-Fatal "Podman machine failed to start. Verify WSL2 is functional."
}
$ErrorActionPreference = "Stop"
Write-OK "Rootful Podman backend running"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2: STAGING ARCHITECTURE SCRIPTS
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 2 "Staging System-Native Build Layers"

if (Test-Path $B) { Remove-Item -Recurse -Force $B }
New-Item -ItemType Directory -Path $B -Force | Out-Null
foreach ($p in "base", "desktop", "hardware", "virtualization", "system") {
    New-Item -ItemType Directory -Path "$B\build_files\$p" -Force | Out-Null
}

# ══════════════════════════════════════════════════════════════════════════════
#  01-repos.sh — Repository initialization
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# RPMFusion (Free + Nonfree) for NVIDIA drivers and multimedia codecs
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-rawhide.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-rawhide.noarch.rpm

echo "[01-repos] Fedora Rawhide + RPMFusion Free/Nonfree initialized."
'@ | Out-File -FilePath "$B\build_files\base\01-repos.sh" -Encoding ascii

# ══════════════════════════════════════════════════════════════════════════════
#  02-kernel.sh — Kernel upgrade + devel headers for akmods
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

dnf upgrade -y --refresh kernel kernel-core kernel-modules
dnf install -y kernel-devel kernel-headers python3

KVER=$(ls /lib/modules | sort -V | tail -n 1)
echo "[02-kernel] Native Fedora Rawhide kernel secured: $KVER"
'@ | Out-File -FilePath "$B\build_files\base\02-kernel.sh" -Encoding ascii

# ══════════════════════════════════════════════════════════════════════════════
#  01-gnome.sh — Full GNOME 50 desktop + Flatpak + theme
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# Full GNOME 50 desktop + essential user-facing packages
dnf install -y --skip-unavailable \
    @gnome-desktop \
    gnome-tweaks gnome-shell-extensions gnome-themes-extra adwaita-cursor-theme \
    gdm ptyxis \
    xdg-user-dirs xdg-utils xdg-desktop-portal xdg-desktop-portal-gnome \
    pipewire pipewire-pulseaudio wireplumber \
    flatpak epiphany dconf \
    gnome-software gnome-system-monitor gnome-disk-utility \
    nautilus file-roller evince loupe totem

systemctl enable gdm.service NetworkManager.service
systemctl set-default graphical.target

# Flathub remotes
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true

# Pre-install essential Flatpaks
flatpak install -y --noninteractive flathub \
    com.mattjakeman.ExtensionManager \
    io.podman_desktop.PodmanDesktop \
    com.visualstudio.code 2>/dev/null || true

# GDM Wayland-native configuration
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'EOF'
[daemon]
WaylandEnable=true
DefaultSession=gnome-wayland.desktop

[security]

[xdmcp]

[chooser]

[debug]
EOF

# System-wide dark theme via dconf
mkdir -p /etc/dconf/profile
echo -e "user\nsystem-db:local" > /etc/dconf/profile/user
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-cloudws <<'EOF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
font-name='Cantarell 11'
document-font-name='Cantarell 11'
monospace-font-name='Source Code Pro 10'

[org/gnome/desktop/wm/preferences]
theme='Adwaita'

[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop','org.gnome.Ptyxis.desktop','epiphany.desktop','org.gnome.Software.desktop','cockpit.desktop']
EOF
dconf update

# Environment variables for Wayland-native apps
mkdir -p /etc/environment.d
cat > /etc/environment.d/50-cloudws.conf <<'EOF'
QT_QPA_PLATFORMTHEME=gnome
ELECTRON_OZONE_PLATFORM_HINT=auto
MOZ_ENABLE_WAYLAND=1
EOF

# GTK settings
mkdir -p /etc/gtk-3.0 /etc/gtk-4.0
cat > /etc/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-font-name=Cantarell 11
EOF
cat > /etc/gtk-4.0/settings.ini <<'EOF'
[Settings]
gtk-font-name=Cantarell 11
EOF

# Portal routing
mkdir -p /usr/share/xdg-desktop-portal
cat > /usr/share/xdg-desktop-portal/gnome-portals.conf <<'EOF'
[preferred]
default=gnome;gtk;
EOF

echo "[01-gnome] GNOME 50 + Flatpaks + dark theme + environment initialized."
'@ | Out-File -FilePath "$B\build_files\desktop\01-gnome.sh" -Encoding ascii

# ══════════════════════════════════════════════════════════════════════════════
#  01-hardware.sh — AMD iGPU + NVIDIA dGPU + kernel modules
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# ─── AMD iGPU (RDNA2 — Ryzen 9 9950X3D integrated graphics) ─────────────────
dnf install -y --skip-unavailable \
    mesa-vulkan-drivers mesa-dri-drivers mesa-va-drivers mesa-vdpau-drivers \
    vulkan-loader vulkan-tools libva-utils \
    linux-firmware amd-ucode microcode_ctl

# ROCm OpenCL / HIP for compute workloads on the iGPU
dnf install -y --skip-unavailable rocm-opencl rocm-hip

# ─── NVIDIA dGPU (RTX 4090 — Ada Lovelace, GSP Firmware) ────────────────────
dnf install -y --skip-unavailable \
    akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-container-toolkit

# Build NVIDIA kmod against the highest installed kernel
KVER=$(ls /lib/modules | sort -V | tail -n 1)
echo "[01-hardware] Building NVIDIA kmod for kernel: $KVER"
akmods --force --kernels "$KVER"

# Generate CDI spec for GPU containers (Podman + Kubernetes)
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.json 2>/dev/null || true

mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_EnableGpuFirmware=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# ─── NTSync + VFIO + hv_sock kernel modules at boot ─────────────────────────
mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/cloudws.conf <<'EOF'
ntsync
vfio-pci
hv_sock
EOF

echo "[01-hardware] AMD iGPU + NVIDIA dGPU + NTSync + VFIO initialized on $KVER."
'@ | Out-File -FilePath "$B\build_files\hardware\01-hardware.sh" -Encoding ascii

# ══════════════════════════════════════════════════════════════════════════════
#  01-virt.sh — MASSIVE: Full virtualization + security + services + tools
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# ─── Virtualisation Stack ────────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    qemu-kvm libvirt virt-install virt-manager \
    edk2-ovmf swtpm swtpm-tools dnsmasq mdevctl libguestfs-tools \
    lm_sensors btop nvtop intel-gpu-tools

# ─── Container & Image Forge Toolchain ───────────────────────────────────────
dnf install -y --skip-unavailable \
    podman podman-compose buildah skopeo \
    bootc bootc-image-builder osbuild osbuild-composer osbuild-selinux \
    composer-cli rpm-ostree \
    crun netavark aardvark-dns slirp4netns composefs

# ─── Cockpit Ecosystem (includes Image Builder UI) ──────────────────────────
dnf install -y --skip-unavailable \
    cockpit cockpit-system \
    cockpit-machines cockpit-podman cockpit-ostree \
    cockpit-storaged cockpit-networkmanager cockpit-selinux \
    cockpit-image-builder \
    pcp cockpit-pcp pcp-zeroconf

# ─── Security & IPS ─────────────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    firewalld chrony zram-generator \
    fapolicyd usbguard \
    policycoreutils-python-utils checkpolicy

# ─── CrowdSec IPS — Sovereign Mode (no outbound telemetry) ──────────────────
echo "[01-virt] Installing CrowdSec IPS (sovereign/offline mode)..."
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | os=fedora dist=42 bash || true
dnf install -y --skip-unavailable --allowerasing --nobest crowdsec crowdsec-firewall-bouncer-nftables

# CrowdSec sovereign mode config
mkdir -p /etc/crowdsec
cat > /etc/crowdsec/config.yaml.local <<'EOCSC'
# CloudWS Sovereign Mode — CrowdSec sends NOTHING outbound
api:
  server:
    online_client:
      credentials_path: ""
cscli:
  output: human
crowdsec_service:
  enable: true
plugin_config:
  user: nobody
  group: nogroup
EOCSC

# *** THE FIX: CrowdSec ACQUISITION CONFIG — without this, agent refuses to start ***
mkdir -p /etc/crowdsec/acquis.d
cat > /etc/crowdsec/acquis.d/journalctl.yaml <<'EOACQ'
# CloudWS — Monitor SSH via journalctl
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=sshd.service"
labels:
  type: syslog
---
# CloudWS — Monitor Cockpit web UI
source: journalctl
journalctl_filter:
  - "_SYSTEMD_UNIT=cockpit.service"
  - "_SYSTEMD_UNIT=cockpit-wsinstance-http.service"
labels:
  type: syslog
---
# CloudWS — Monitor kernel/audit
source: journalctl
journalctl_filter:
  - "SYSLOG_IDENTIFIER=kernel"
labels:
  type: syslog
EOACQ

# Disable CAPI enrollment
mkdir -p /etc/crowdsec/local_api_credentials.yaml.d
cat > /etc/crowdsec/local_api_credentials.yaml.d/sovereign.yaml <<'EOSOV'
url: http://127.0.0.1:8080/
login: ""
password: ""
EOSOV

# Hub update timer needs network
mkdir -p /etc/systemd/system/crowdsec-hubupdate.service.d
cat > /etc/systemd/system/crowdsec-hubupdate.service.d/override.conf <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target
EOF

# Install detection collections at build time
cscli hub update 2>/dev/null || true
cscli collections install crowdsecurity/sshd 2>/dev/null || true
cscli collections install crowdsecurity/linux 2>/dev/null || true

# ─── Performance & Gaming ───────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    tuned tuned-ppd tuned-utils tuned-profiles-cpu-partitioning tuned-profiles-realtime \
    gamemode mangohud steam gamescope

# ─── Hypervisor Guest Agents (VM portability) ────────────────────────────────
dnf install -y --skip-unavailable \
    hyperv-daemons qemu-guest-agent open-vm-tools spice-vdagent

# ─── Remote Access ──────────────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    xrdp xorgxrdp

# ─── Storage & Networking ────────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    cifs-utils virtiofsd lvm2 mdadm btrfs-progs \
    samba samba-client nfs-utils \
    openssh-server tailscale \
    nvme-cli device-mapper-multipath sg3_utils \
    socat nmap-ncat tcpdump iptables-nft conntrack-tools

# ─── High Availability / Clustering ─────────────────────────────────────────
dnf install -y --skip-unavailable --allowerasing --nobest \
    corosync pacemaker pcs fence-agents-all resource-agents \
    keepalived haproxy \
    sanlock libvirt-lock-sanlock \
    iscsi-initiator-utils targetcli ceph-common \
    glusterfs glusterfs-server glusterfs-fuse glusterfs-cli \
    etcd helm wireguard-tools

# ─── System Utilities ────────────────────────────────────────────────────────
dnf install -y --skip-unavailable \
    git jq make curl wget rsync tmux screen tree \
    distrobox cloud-init \
    polkit udisks2 clevis \
    python3 python3-pip python3-devel

# ─── Waydroid (Android in Linux) ────────────────────────────────────────────
dnf install -y --skip-unavailable waydroid

# ─── K3s Lightweight Kubernetes ──────────────────────────────────────────────
echo "[01-virt] Installing K3s..."
curl -sfL https://get.k3s.io -o /usr/local/bin/k3s-install.sh && chmod +x /usr/local/bin/k3s-install.sh || true
curl -sfL "https://github.com/k3s-io/k3s/releases/latest/download/k3s" -o /usr/local/bin/k3s 2>/dev/null || true
chmod +x /usr/local/bin/k3s 2>/dev/null || true
[ -f /usr/local/bin/k3s ] && {
    ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
    ln -sf /usr/local/bin/k3s /usr/local/bin/crictl 2>/dev/null || true
}

cat > /usr/lib/systemd/system/k3s.service <<'K3SVC'
[Unit]
Description=Lightweight Kubernetes
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/local/bin/k3s server
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
[Install]
WantedBy=multi-user.target
K3SVC

# ─── ZRAM Swap (compressed RAM, replaces disk swap) ─────────────────────────
mkdir -p /usr/lib/systemd/zram-generator.conf.d
cat > /usr/lib/systemd/zram-generator.conf.d/cloudws.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 32768)
compression-algorithm = zstd
EOF

# ─── Sysctl VM Host Tuning ──────────────────────────────────────────────────
cat > /etc/sysctl.d/99-cloudws-vmhost.conf <<'EOSYSCTL'
# CloudWS VM Host Tuning
vm.swappiness = 10
vm.overcommit_memory = 1
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.nr_hugepages = 0
vm.hugetlb_shm_group = 36
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192
fs.inotify.max_queued_events = 1048576
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
EOSYSCTL

# ─── Cockpit Listen on All Interfaces ───────────────────────────────────────
mkdir -p /etc/systemd/system/cockpit.socket.d
cat > /etc/systemd/system/cockpit.socket.d/listen.conf <<'EOF'
[Socket]
ListenStream=
ListenStream=9090
EOF

# ─── Bootc Bare-Metal Install Config ────────────────────────────────────────
mkdir -p /usr/lib/bootc/install
cat > /usr/lib/bootc/install/00-cloudws.toml <<'EOF'
[install]
root-fs-type = "xfs"
EOF

# ─── Libvirt Security Config ────────────────────────────────────────────────
mkdir -p /etc/libvirt/qemu.conf.d
cat > /etc/libvirt/qemu.conf.d/10-cloudws.conf <<'EOF'
user = "root"
group = "root"
dynamic_ownership = 1
remember_owner = 0
EOF

# ─── Polkit Rules (passwordless wheel + libvirt) ────────────────────────────
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-nopasswd-wheel.rules <<'EOF'
polkit.addRule(function(a,s){if(s.isInGroup("wheel")){return polkit.Result.YES;}});
EOF
cat > /etc/polkit-1/rules.d/49-nopasswd-libvirt.rules <<'EOF'
polkit.addRule(function(a,s){if(a.id=="org.libvirt.unix.manage"&&s.local&&s.active&&s.isInGroup("libvirt")){return polkit.Result.YES;}});
EOF

# ─── Waydroid Pre-Configuration ─────────────────────────────────────────────
mkdir -p /var/lib/waydroid /etc/waydroid
cat > /etc/waydroid/waydroid.cfg <<'EOWAYDROID'
[waydroid]
system_ota = https://ota.waydro.id/system
vendor_ota = https://ota.waydro.id/vendor
system_type = GAPPS
EOWAYDROID

# ─── xRDP Hyper-V Enhanced Session (vsock transport) ────────────────────────
if [ -f /etc/xrdp/xrdp.ini ]; then
    sed -i 's/^port=3389/port=vsock:\/\/-1:3389/' /etc/xrdp/xrdp.ini
    sed -i 's/^use_vsock=false/use_vsock=true/' /etc/xrdp/xrdp.ini
    sed -i 's/^security_layer=negotiate/security_layer=rdp/' /etc/xrdp/xrdp.ini
fi
if [ -f /etc/xrdp/sesman.ini ]; then
    sed -i 's/^AllowRootLogin=false/AllowRootLogin=true/' /etc/xrdp/sesman.ini 2>/dev/null || true
fi
mkdir -p /etc/X11
echo "allowed_users=anybody" > /etc/X11/Xwrapper.config

# ─── Cockpit Plugins from Upstream Git ──────────────────────────────────────
git clone --depth=1 https://github.com/45Drives/cockpit-benchmark.git /tmp/bench && \
    make -C /tmp/bench install && rm -rf /tmp/bench || true
git clone --depth=1 https://github.com/optimans/cockpit-zfs-manager.git /tmp/zfs && \
    cp -r /tmp/zfs/zfs /usr/share/cockpit/ && rm -rf /tmp/zfs || true

# ─── VirtIO-Win ISO for Windows VMs ────────────────────────────────────────
mkdir -p /var/lib/libvirt/images
curl -Lo /var/lib/libvirt/images/virtio-win.iso \
    'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso' 2>/dev/null || true

# ─── Looking Glass B7 (low-latency GPU passthrough display) ─────────────────
dnf install -y --skip-unavailable --allowerasing --nobest \
    cmake gcc gcc-c++ make pkgconf binutils binutils-devel \
    libX11-devel nettle-devel libXi-devel libXinerama-devel libXcursor-devel libXpresent-devel \
    libxkbcommon-devel wayland-devel wayland-protocols-devel \
    libsamplerate-devel pulseaudio-libs-devel pipewire-devel spice-protocol \
    fontconfig-devel freetype-devel libXScrnSaver-devel libXrandr-devel \
    libdecor-devel libepoxy-devel mesa-libEGL-devel

cd /tmp; rm -rf LookingGlass
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass; git checkout B7; git submodule update --init --recursive
mkdir -p client/build; cd client/build
if cmake ../ && make -j$(nproc); then
    install -Dm755 looking-glass-client /usr/local/bin/looking-glass-client
    echo "[01-virt] Looking Glass B7 built successfully"
else
    echo "[01-virt] WARN: Looking Glass build failed (non-fatal)"
fi
rm -rf /tmp/LookingGlass

# Remove Looking Glass build deps (keep runtime deps)
dnf remove -y --noautoremove cmake gcc gcc-c++ pkgconf binutils-devel \
    libX11-devel nettle-devel libXi-devel libXinerama-devel libXcursor-devel libXpresent-devel \
    libxkbcommon-devel wayland-devel wayland-protocols-devel \
    libsamplerate-devel pulseaudio-libs-devel pipewire-devel spice-protocol \
    fontconfig-devel freetype-devel libXScrnSaver-devel libXrandr-devel \
    libdecor-devel libepoxy-devel mesa-libEGL-devel 2>/dev/null || true

echo 'SUBSYSTEM=="kvmfr", OWNER="root", GROUP="kvm", MODE="0660"' > /etc/udev/rules.d/99-kvmfr.rules
echo "f /dev/shm/looking-glass 0660 root kvm -" > /etc/tmpfiles.d/10-looking-glass.conf
cat > /usr/local/bin/looking-glass-start <<'EOF'
#!/bin/bash
while [[ ! -e /dev/shm/looking-glass ]]; do sleep 1; done
exec /usr/local/bin/looking-glass-client -F -f /dev/shm/looking-glass
EOF
chmod +x /usr/local/bin/looking-glass-start

# ─── Gamescope SteamOS-Mode GDM Session ─────────────────────────────────────
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/steam.desktop <<'EOF'
[Desktop Entry]
Name=Steam (Gamescope)
Comment=SteamOS-mode gaming session
Exec=gamescope -e -f -- steam -tenfoot -steamos
Type=Application
DesktopNames=gamescope
EOF

# ─── Service Enablement ─────────────────────────────────────────────────────
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket osbuild-composer.socket sshd.service
systemctl enable tuned.service pmcd.service pmlogger.service pmproxy.service
systemctl enable firewalld.service chronyd.service
systemctl enable crowdsec.service crowdsec-firewall-bouncer.service
systemctl enable fapolicyd.service usbguard.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service hypervvssd.service hypervkvpd.service 2>/dev/null || true
systemctl enable smb.service nmb.service nfs-server.service 2>/dev/null || true
systemctl enable tailscaled.service xrdp.service xrdp-sesman.service 2>/dev/null || true
systemctl enable waydroid-container.service cloud-init.service 2>/dev/null || true
systemctl enable pcsd.service multipathd.service 2>/dev/null || true
systemctl enable podman.socket podman-auto-update.timer podman-restart.service 2>/dev/null || true

# TuneD default profile
tuned-adm profile throughput-performance 2>/dev/null || true

echo "[01-virt] Full KVM/Podman/Gaming/Security/Cockpit + Looking Glass B7 installed."
'@ | Out-File -FilePath "$B\build_files\virtualization\01-virt.sh" -Encoding ascii

# ══════════════════════════════════════════════════════════════════════════════
#  99-overrides.sh — User, hostname, firewall, GPU detect, init, SELinux, tools
# ══════════════════════════════════════════════════════════════════════════════
$Ovr = @'
#!/bin/bash
set -euo pipefail

# ═══ 1. CREATE USER ═══
useradd -m -s /bin/bash INJ_U 2>/dev/null || true
cat <<'EOF' | chpasswd
INJ_U:INJ_P
root:INJ_P
EOF

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

# ═══ 4. SHELL ALIASES ═══
echo 'alias scan-malware="podman run --rm -v ~/.clamav:/var/lib/clamav -v /var/home:/scandir:ro docker.io/clamav/clamav:latest clamscan -r /scandir"' >> /etc/skel/.bashrc

# ═══ 5. LOCALE ═══
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

# ═══ 6. HOSTNAME ═══
echo "CloudWS" > /etc/hostname
echo -e "127.0.0.1 localhost\n127.0.1.1 CloudWS CloudWS.local\n::1 localhost" > /etc/hosts
echo -e "PRETTY_HOSTNAME=\"CloudWS\"\nICON_NAME=\"computer\"\nCHASSIS=\"server\"" > /etc/machine-info
mkdir -p /etc/NetworkManager/conf.d
echo -e "[main]\nhostname-mode=none" > /etc/NetworkManager/conf.d/hostname.conf

cat > /usr/lib/systemd/system/cloudws-hostname.service <<'EOSVC'
[Unit]
Description=Enforce CloudWS Hostname
After=local-fs.target
Before=systemd-hostnamed.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo CloudWS > /etc/hostname; hostnamectl set-hostname CloudWS 2>/dev/null || true'
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

# ═══ 9. FIREWALL INIT — ALL PORTS FOR ALL SERVICES ═══
cat > /usr/libexec/cloudws-firewall-init <<'EOFW'
#!/bin/bash
if ! command -v firewall-cmd &>/dev/null; then exit 0; fi
if ! systemctl is-active firewalld &>/dev/null; then exit 0; fi

# Default deny
firewall-cmd --set-default-zone=drop 2>/dev/null || true

# ── Core services ──
firewall-cmd --permanent --zone=drop --add-service=cockpit   # 9090/tcp
firewall-cmd --permanent --zone=drop --add-service=ssh       # 22/tcp
firewall-cmd --permanent --zone=drop --add-service=mdns      # 5353/udp

# ── Remote Desktop (xRDP) ──
firewall-cmd --permanent --zone=drop --add-port=3389/tcp     # RDP standard
firewall-cmd --permanent --zone=drop --add-port=3390/tcp     # RDP alternate

# ── Samba/CIFS ──
firewall-cmd --permanent --zone=drop --add-service=samba      # 139,445/tcp

# ── NFS ──
firewall-cmd --permanent --zone=drop --add-service=nfs        # 2049/tcp
firewall-cmd --permanent --zone=drop --add-service=rpc-bind   # 111/tcp+udp
firewall-cmd --permanent --zone=drop --add-service=mountd     # dynamic

# ── Libvirt / SPICE / VNC ──
firewall-cmd --permanent --zone=drop --add-port=16509/tcp     # libvirt TLS
firewall-cmd --permanent --zone=drop --add-port=5900-5999/tcp # VNC/SPICE

# ── K3s Kubernetes API ──
firewall-cmd --permanent --zone=drop --add-port=6443/tcp
firewall-cmd --permanent --zone=drop --add-port=10250/tcp     # kubelet

# ── Pacemaker/Corosync HA ──
firewall-cmd --permanent --zone=drop --add-port=2224/tcp      # pcsd
firewall-cmd --permanent --zone=drop --add-port=5403-5405/udp # corosync

# ── Trusted internal interfaces (containers, VMs, localhost) ──
firewall-cmd --permanent --zone=trusted --add-interface=lo
firewall-cmd --permanent --zone=trusted --add-interface=podman0
firewall-cmd --permanent --zone=trusted --add-interface=virbr0
firewall-cmd --permanent --zone=trusted --add-interface=cni0
firewall-cmd --permanent --zone=trusted --add-interface=flannel.1
firewall-cmd --permanent --zone=trusted --add-interface=waydroid0
firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true

# ── Trusted subnets (K3s pods/services, libvirt default, podman) ──
firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16   # K3s pods
firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16   # K3s services
firewall-cmd --permanent --zone=trusted --add-source=10.88.0.0/16   # Podman default
firewall-cmd --permanent --zone=trusted --add-source=192.168.122.0/24 # libvirt default
firewall-cmd --permanent --zone=trusted --add-source=192.168.124.0/24 # libvirt isolated
firewall-cmd --permanent --zone=trusted --add-source=127.0.0.0/8    # loopback

firewall-cmd --reload
echo "[cloudws-firewall-init] Firewall configured — drop zone + service ports + trusted networks"
EOFW
chmod +x /usr/libexec/cloudws-firewall-init

# ═══ 10. GPU AUTO-DETECT SERVICE (blocks NVIDIA in VMs, runs BEFORE GDM) ═══
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
if [ "$VIRT" != "none" ]; then
    echo "[cloudws-gpu-detect] Virtual machine detected ($VIRT) — blocking NVIDIA modules"
    cat > "$NVIDIA_CONF" <<'EOMOD'
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nvidia_uvm /bin/false
EOMOD
    for mod in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
        modprobe -r "$mod" 2>/dev/null || true
    done
    case "$VIRT" in
        microsoft|wsl) modprobe hyperv_drm 2>/dev/null || true ;;
        kvm|qemu)      modprobe virtio-gpu 2>/dev/null || true ;;
        vmware)        modprobe vmwgfx 2>/dev/null || true ;;
    esac
else
    echo "[cloudws-gpu-detect] Bare metal — NVIDIA modules enabled"
    rm -f "$NVIDIA_CONF"
fi
touch /run/cloudws-gpu-detected
echo "[cloudws-gpu-detect] GPU environment configured."
EOGPU
chmod +x /usr/libexec/cloudws-gpu-detect
systemctl enable cloudws-gpu-detect.service

# ═══ 11. EVERY-BOOT SYSTEM INIT SERVICE ═══
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
hostnamectl set-hostname CloudWS 2>/dev/null || true

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

# Flatpak dark theme + appstream
flatpak override --system --env=GTK_THEME=Adwaita:dark 2>/dev/null || true
flatpak update --appstream 2>/dev/null || true

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
        done
        ;;
    bind|unbind|status)
        if ! command -v driverctl &>/dev/null; then echo "driverctl not found"; exit 1; fi
        driverctl "$@"
        ;;
    *) echo "Usage: cloudws-vfio-toggle {list|bind|unbind|status} [device]" ;;
esac
EOVFIO
chmod +x /usr/local/bin/cloudws-vfio-toggle

# iommu-groups visualization
cat > /usr/local/bin/iommu-groups <<'EOIOMMU'
#!/bin/bash
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
    echo -e "\033[1;34mIOMMU Group ${g##*/}:\033[0m"
    for d in "$g"/devices/*; do echo "  $(lspci -nns "${d##*/}")"; done
done
EOIOMMU
chmod +x /usr/local/bin/iommu-groups

# Cockpit desktop launcher
mkdir -p /usr/share/applications
cat > /usr/share/applications/cockpit.desktop <<'EOCOCK'
[Desktop Entry]
Type=Application
Name=CloudWS Cockpit
Comment=Web-based server management
Exec=xdg-open https://localhost:9090
Icon=utilities-system-monitor
Categories=System;
EOCOCK

# ═══ 13. SELINUX BUILD-TIME FIXES ═══
if command -v restorecon &>/dev/null; then
    restorecon -R /boot /etc /usr /var 2>/dev/null || true
fi
if command -v semanage &>/dev/null; then
    semanage fcontext -a -t boot_t '/boot/bootupd-state.json' 2>/dev/null || true
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true
    semanage fcontext -a -t accountsd_var_lib_t '/usr/share/accountsservice/interfaces(/.*)?'  2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
fi
if command -v setsebool &>/dev/null; then
    setsebool -P daemons_dump_core on 2>/dev/null || true
    setsebool -P domain_can_mmap_files on 2>/dev/null || true
    setsebool -P virt_sandbox_use_all_caps on 2>/dev/null || true
    setsebool -P virt_use_nfs on 2>/dev/null || true
fi

# ═══ 14. SKELETON AUTOSTART ═══
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/cloudws-user-setup.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=CloudWS User Setup
Exec=bash -c "sleep 8 && flatpak install -y flathub-beta com.usebottles.bottles 2>/dev/null; rm -f ~/.config/autostart/cloudws-user-setup.desktop"
Hidden=false
X-GNOME-Autostart-enabled=true
DESK

echo "[99-overrides] CloudWS fully configured — user, hostname, firewall, GPU detect, CrowdSec, tools."
'@
$Ovr.Replace('INJ_U',$U).Replace('INJ_P',$P) | Out-File -FilePath "$B\build_files\system\99-overrides.sh" -Encoding ascii

Write-OK "All architecture layer scripts staged (repos, kernel, GNOME, hardware, virt+security, overrides)"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3: ASSEMBLE CONTAINERFILE & BUILD OCI IMAGE
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 3 "OCI Container Build [expect 30–60 minutes]"

$containerfile = @'
# ── Stage 1: Build context ──────────────────────────────────────────────────
FROM scratch AS ctx
COPY build_files /build_files

# ── Stage 2: Fedora Rawhide Bootc base ──────────────────────────────────────
FROM quay.io/fedora/fedora-bootc:rawhide

# Full system upgrade first
RUN dnf upgrade -y --refresh

# Execute all architecture layers in a single RUN to minimize image layers
RUN --mount=type=bind,from=ctx,source=/build_files,target=/tmp/staging \
    mkdir -p /tmp/scripts && \
    cp -r /tmp/staging/* /tmp/scripts/ && \
    find /tmp/scripts -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    chmod +x /tmp/scripts/*/*.sh && \
    bash /tmp/scripts/base/01-repos.sh && \
    bash /tmp/scripts/base/02-kernel.sh && \
    bash /tmp/scripts/desktop/01-gnome.sh && \
    bash /tmp/scripts/hardware/01-hardware.sh && \
    bash /tmp/scripts/virtualization/01-virt.sh && \
    bash /tmp/scripts/system/99-overrides.sh && \
    dnf clean all && \
    rm -rf /var/cache/dnf /tmp/scripts

LABEL containers.bootc 1
RUN bootc container lint
'@
$containerfile | Out-File -FilePath "$B\Containerfile" -Encoding ascii
Write-OK "Containerfile assembled"

$t0 = Get-Date
Invoke-Cmd "Executing Podman build (all $cpuCount threads)..." {
    podman build --no-cache -t "${ImageName}:${ImageTag}" $B
}
$elapsed = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
Write-OK "OCI image built in ${elapsed} minutes → ${ImageName}:${ImageTag}"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4: TARGET SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 4 "Generating Deployment Targets"

# ── Target 1: RAW ────────────────────────────────────────────────────────────
Write-Step "TARGET 1 — Building RAW disk image via bootc-image-builder..."
$ErrorActionPreference = "Continue"
& podman run --rm -it --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    -v "${OutputFolder}:/output:z" `
    quay.io/centos-bootc/bootc-image-builder:latest `
    build --type raw --rootfs ext4 --local $LocalImage

$genRaw = Get-ChildItem $OutputFolder -Filter "disk.raw" -Recurse -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genRaw) {
    Move-Item $genRaw.FullName $RawImg -Force
    Write-OK "RAW image: $(Get-FileSize $RawImg)"
} else {
    Write-Warn "RAW image generation failed — downstream VHDX will be skipped"
}
$ErrorActionPreference = "Stop"

# ── Target 2: VHDX ──────────────────────────────────────────────────────────
Write-Step "TARGET 2 — Converting RAW to Hyper-V Gen2 VHDX..."
if (Test-Path $RawImg) {
    $rawLeaf = Split-Path $RawImg -Leaf
    & podman run --rm -v "${OutputFolder}:/data:z" docker.io/alpine:latest `
        sh -c "apk add --no-cache qemu-img && qemu-img convert -p -f raw -O vhdx -o subformat=dynamic /data/$rawLeaf /data/cloudws-hyperv.vhdx"
    if ($LASTEXITCODE -eq 0) { Write-OK "VHDX conversion complete: $(Get-FileSize $TargetVhdx)" }
    else { Write-Warn "VHDX conversion failed" }
} else {
    Write-Warn "Skipped VHDX — no RAW base image"
}

# ── Target 3: WSL2 ──────────────────────────────────────────────────────────
Write-Step "TARGET 3 — Exporting WSL2 + WSLg tarball..."
$ErrorActionPreference = "Continue"
& podman rm wsl-exp-tmp 2>$null
& podman create --name wsl-exp-tmp "${ImageName}:${ImageTag}" | Out-Null
& podman export -o $TargetWsl wsl-exp-tmp
& podman rm wsl-exp-tmp | Out-Null
$ErrorActionPreference = "Stop"

if (Test-Path $TargetWsl) { Write-OK "WSL tarball: $(Get-FileSize $TargetWsl)" }
else { Write-Warn "WSL tarball export failed" }

# ── Target 4: Anaconda ISO ──────────────────────────────────────────────────
Write-Step "TARGET 4 — Generating Anaconda installer ISO..."
$ErrorActionPreference = "Continue"
& podman run --rm -it --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    -v "${OutputFolder}:/output:z" `
    quay.io/centos-bootc/bootc-image-builder:latest `
    build --type anaconda-iso --rootfs ext4 --local $LocalImage

$genIso = Get-ChildItem $OutputFolder -Filter "*.iso" -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -ne "cloudws-installer.iso" } |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genIso) {
    Move-Item $genIso.FullName $TargetIso -Force
    Write-OK "Anaconda ISO: $(Get-FileSize $TargetIso)"
} else {
    Write-Warn "Anaconda ISO generation failed"
}
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: REGISTRY SYNCHRONIZATION (GHCR)
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 5 "Remote Registry Synchronization (GHCR)"

Write-Step "Tagging local image → $GhcrImage"
& podman tag $LocalImage $GhcrImage

Write-Step "Pushing to GHCR..."
$ErrorActionPreference = "Continue"
$pushResult = & podman push $GhcrImage 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "Image pushed to GHCR successfully"
    $GhcrOK = $true
} else {
    Write-Warn "GHCR push failed. Run 'podman login ghcr.io' with a PAT first."
    Write-Warn "Details: $pushResult"
    $GhcrOK = $false
}
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  FINAL STATUS REPORT
# ══════════════════════════════════════════════════════════════════════════════
$T1OK = Test-Path $RawImg
$T2OK = Test-Path $TargetVhdx
$T3OK = Test-Path $TargetWsl
$T4OK = Test-Path $TargetIso
$AllOK = $T1OK -and $T2OK -and $T3OK -and $T4OK -and $GhcrOK
$totalElapsed = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)

$reportColor = if ($AllOK) { "Green" } else { "Yellow" }
Write-Host ""
Write-Host "  $("═" * 78)" -ForegroundColor $reportColor
Write-Host "   CLOUD-WS DEPLOYMENT PIPELINE — COMPLETE  (total: ${totalElapsed} min)" -ForegroundColor $reportColor
Write-Host "  $("═" * 78)" -ForegroundColor $reportColor
Write-Host ""

Write-TargetReport 1 "Bare Metal RAW"     $T1OK  $RawImg     "Flash via Rufus (DD mode) or: dd if=cloudws-bootable.raw of=/dev/sdX bs=4M"
Write-TargetReport 2 "Hyper-V Gen2 VHDX"  $T2OK  $TargetVhdx "New Gen2 VM → Disable Secure Boot → attach VHDX as boot disk"
Write-TargetReport 3 "WSL2 + WSLg Distro" $T3OK  $TargetWsl  "wsl --import CloudWS C:\WSL\CloudWS '$TargetWsl' && wsl -d CloudWS"
Write-TargetReport 4 "Anaconda ISO"        $T4OK  $TargetIso  "Write to USB with Rufus (ISO mode) — Anaconda installer"
Write-TargetReport 5 "GHCR Registry"       $GhcrOK $GhcrImage "sudo bootc switch $GhcrImage"

Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  Default credentials : $U / $P                              │" -ForegroundColor Yellow
Write-Host "  │  Upgrade any target  : sudo bootc upgrade                   │" -ForegroundColor DarkGray
Write-Host "  │  Switch image source : sudo bootc switch $GhcrImage         │" -ForegroundColor DarkGray
Write-Host "  │  GPU stack           : AMD RDNA2 iGPU + NVIDIA RTX 4090     │" -ForegroundColor DarkGray
Write-Host "  │  Cockpit dashboard   : https://localhost:9090                │" -ForegroundColor DarkGray
Write-Host "  │  Image Builder UI    : https://localhost:9090/composer       │" -ForegroundColor DarkGray
Write-Host "  │  RDP access          : port 3389 (standard) / 3390 (alt)    │" -ForegroundColor DarkGray
Write-Host "  │  SSH access          : port 22                              │" -ForegroundColor DarkGray
Write-Host "  │  Security            : CrowdSec IPS + fapolicyd + USBGuard  │" -ForegroundColor DarkGray
Write-Host "  │  Firewall            : default-deny drop + trusted internal │" -ForegroundColor DarkGray
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""
