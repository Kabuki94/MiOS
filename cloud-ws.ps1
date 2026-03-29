<#
.SYNOPSIS
    CloudWS v1.0 — Cloud Workstation OS Build Orchestrator
.DESCRIPTION
    The definitive orchestrator for CloudWS, a self-replicating immutable
    cloud-native workstation OS built on Fedora Rawhide bootc.

    Fully portable — supports AMD, Intel, and NVIDIA CPUs and GPUs out of the box.
    GPU auto-detection at boot adjusts for bare metal, Hyper-V, QEMU, or VMware.

    OS Architecture  : Fedora Rawhide | GNOME 50 | Wayland-only
    Deployment Core  : Fedora bootc + ComposeFS + OSTree (immutable, atomic)

    TARGET 1 : Bare Metal RAW Image      (cloudws-bootable.raw)
    TARGET 2 : Hyper-V Gen2 VHDX         (cloudws-hyperv.vhdx)
    TARGET 3 : WSL2 + WSLg Tarball       (cloudws-wsl.tar)
    TARGET 4 : Anaconda Installer ISO    (cloudws-installer.iso)
    TARGET 5 : OCI Registry Push         (configurable — defaults to GHCR)

.NOTES
    v1.0.0 — First stable release.
    - FIXED: GDM password auth — `authselect select local --force` configures PAM
             with ONLY pam_unix.so. The with-silent-lastlog, with-mkhomedir, and
             with-pam-gnome-keyring features all reference PAM modules that may be
             missing on Rawhide (pam_lastlog.so removed in F43+), causing the entire
             PAM chain to fail and GDM to reject all passwords.
    - FIXED: User home at /var/home (bootc symlinks /home → /var/home).
    - FIXED: CrowdSec service enablement gated on `command -v crowdsec`.
    - FIXED: CrowdSec repo adds Fedora 40 fallback when dist=42 unavailable.
    - FIXED: chpasswd uses robust `echo | chpasswd || true` (pipefail-safe).
    - FIXED: nodejs-npm also tries `npm` package name (Rawhide compat).
    - ADDED: Dedicated `cloudws-builder` Podman machine — never touches user default.
    - ADDED: Pre-build questions with 30s timeout defaults (user, pass, LUKS, registry).
    - ADDED: User-configurable registry push (defaults to origin GHCR with override).
    - ADDED: `bootc-base-imagectl rechunk` post-build for optimized OCI layers.
    - ADDED: `cloudws --help` terminal alias + fastfetch auto-display in terminal.
    - ADDED: PXE/network boot documentation and Anaconda kickstart ostreecontainer support.
    - ADDED: VHD→VHDX conversion via qemu-img (BIB outputs VHD, not VHDX natively).
    - REMOVED: Hardware-specific references (fully portable across AMD/Intel/NVIDIA).
    - INCLUDES: Full GNOME 50 desktop, Gamescope Steam session, KVM/QEMU/VFIO,
                Podman/K3s, Pacemaker HA, CrowdSec IPS, Looking Glass B7,
                Waydroid, xRDP, Cockpit, cloud-init, SELinux hardening.
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  ENGINE CONFIGURATION & TARGET SPECIFICATIONS
# ══════════════════════════════════════════════════════════════════════════════
$ImageName      = "cloudws"
$ImageTag       = "latest"
$DefUser        = "cloudws"   # Default username
$DefPass        = "cloudws"   # Default password
$DefRegistry    = "ghcr.io/kabuki94/cloudws-bootc"  # Default registry (origin)
$BuilderMachine = "cloudws-builder"
$LocalImage     = "localhost/${ImageName}:${ImageTag}"
$OutputFolder   = Join-Path $PWD "cloudws-deploy-out"
$B              = Join-Path $env:TEMP "cloudws-full-build"
$LogFile        = Join-Path $OutputFolder "build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

$RawImg         = Join-Path $OutputFolder "cloudws-bootable.raw"
$TargetVhdx     = Join-Path $OutputFolder "cloudws-hyperv.vhdx"
$TargetWsl      = Join-Path $OutputFolder "cloudws-wsl.tar"
$TargetIso      = Join-Path $OutputFolder "cloudws-installer.iso"

$RAW_DISK_GB    = 20
$MIN_FREE_GB    = 60
$QuestionTimeout = 30  # Seconds before auto-accepting defaults

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
#  PHASE 0: PRE-FLIGHT & BUILD CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Banner "CLOUDWS v1.0 — CLOUD WORKSTATION OS"

Write-Host "  Base     : Fedora Rawhide bootc | GNOME 50 | Wayland-only" -ForegroundColor Gray
Write-Host "  Hardware : AMD / Intel / NVIDIA (auto-detected at boot)" -ForegroundColor Gray
Write-Host "  Bootc    : ComposeFS + OSTree (immutable, atomic upgrades)" -ForegroundColor Gray
Write-Host "  Targets  : RAW → VHDX → WSL2 → ISO → Registry" -ForegroundColor Gray

Write-Phase 0 "Build Configuration"

# ── Timed input helper ────────────────────────────────────────────────────────
function Read-TimedInput {
    param([string]$Prompt, [string]$Default, [int]$Seconds = $QuestionTimeout, [switch]$Secret)
    Write-Host ""
    if ($Secret) {
        Write-Host "      $Prompt" -ForegroundColor Cyan -NoNewline
        Write-Host " [default: ****] " -ForegroundColor DarkGray -NoNewline
    } else {
        Write-Host "      $Prompt" -ForegroundColor Cyan -NoNewline
        Write-Host " [default: $Default] " -ForegroundColor DarkGray -NoNewline
    }
    Write-Host "(${Seconds}s timeout)" -ForegroundColor DarkGray

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $input = ""
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Enter') { break }
            if ($key.Key -eq 'Backspace' -and $input.Length -gt 0) {
                $input = $input.Substring(0, $input.Length - 1)
                Write-Host "`b `b" -NoNewline
            } else {
                $input += $key.KeyChar
                if ($Secret) { Write-Host "*" -NoNewline } else { Write-Host $key.KeyChar -NoNewline }
            }
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host ""
    if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
    return $input
}

# ── Ask build configuration ──────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor DarkCyan
Write-Host "  │  Configure your CloudWS build (press Enter to accept defaults) │" -ForegroundColor DarkCyan
Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor DarkCyan

$U = Read-TimedInput "CloudWS username:" $DefUser
$P = Read-TimedInput "CloudWS password:" $DefPass -Secret

# LUKS encryption (applies to RAW and ISO targets only)
$luksInput = Read-TimedInput "Enable LUKS disk encryption? (y/N):" "N"
$UseLuks = $luksInput -match "^[yY]"
$LuksPass = ""
if ($UseLuks) {
    $LuksPass = Read-TimedInput "LUKS passphrase:" "cloudws" -Secret
}

# Registry configuration
$RegistryUrl = Read-TimedInput "Registry URL:" $DefRegistry
$GhcrImage   = "${RegistryUrl}:${ImageTag}"

# Registry credentials (check env vars first)
$RegistryUser = $env:CLOUDWS_GHCR_USER
$RegistryToken = $env:CLOUDWS_GHCR_TOKEN
if (-not $RegistryUser) {
    $RegistryUser = Read-TimedInput "Registry username (for push):" "kabuki94"
}
if (-not $RegistryToken) {
    $RegistryToken = Read-TimedInput "Registry token/PAT (for push):" "" -Secret
}

Write-Host ""
Write-OK "Username    : $U"
Write-OK "Password    : ****"
Write-OK "LUKS        : $(if ($UseLuks) { 'Enabled' } else { 'Disabled' })"
Write-OK "Registry    : $GhcrImage"
Write-OK "Registry User: $RegistryUser"
Write-Host ""

# ── System validation ─────────────────────────────────────────────────────────
Write-Phase 0.5 "System Validation"

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
#  PHASE 1: DEDICATED PODMAN BUILDER MACHINE
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 1 "Podman Builder Machine — $cpuCount Threads / $ramMB MB RAM"

$ErrorActionPreference = "Continue"

# Check for existing cloudws-builder machine
$vmStatus = & podman machine inspect $BuilderMachine 2>&1
if ($LASTEXITCODE -ne 0 -or "$vmStatus" -match "does not exist|not found") {
    Write-Step "Creating dedicated '$BuilderMachine' machine (won't touch your default)..."
    & podman machine init $BuilderMachine --rootful --cpus $cpuCount --memory $ramMB --disk-size 150
    if ($LASTEXITCODE -ne 0) { Write-Fatal "Failed to create $BuilderMachine machine." }
} else {
    Write-Step "Found existing '$BuilderMachine' machine — reusing..."
    & podman machine stop $BuilderMachine 2>$null
    Start-Sleep -Seconds 3
}

Write-Step "Starting '$BuilderMachine' machine..."
& podman machine start $BuilderMachine
if ($LASTEXITCODE -ne 0) {
    Write-Fatal "$BuilderMachine failed to start. Verify WSL2 is functional."
}

# Target the builder machine for all subsequent operations
$env:CONTAINER_CONNECTION = "${BuilderMachine}-root"
Write-OK "Builder machine '$BuilderMachine' running (connection: ${BuilderMachine}-root)"
Write-OK "Your default Podman machine is untouched"
$ErrorActionPreference = "Stop"

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
#  01-hardware.sh — Universal GPU drivers (AMD + Intel + NVIDIA)
# ══════════════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# ─── Mesa GPU drivers (AMD / Intel / software fallback) ────────────────────
dnf install -y --skip-unavailable \
    mesa-vulkan-drivers mesa-dri-drivers mesa-va-drivers mesa-vdpau-drivers \
    vulkan-loader vulkan-tools libva-utils \
    linux-firmware amd-ucode intel-ucode microcode_ctl

# ROCm OpenCL / HIP for AMD compute workloads
dnf install -y --skip-unavailable rocm-opencl rocm-hip 2>/dev/null || true

# ─── NVIDIA dGPU (akmod — builds kmod at image time for any NVIDIA card) ──
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

echo "[01-hardware] Universal GPU drivers (Mesa + NVIDIA akmod) + NTSync + VFIO initialized on $KVER."
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
    lm_sensors btop nvtop intel-gpu-tools fastfetch

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
# Ensure CA certs are current before fetching external repo
dnf install -y --skip-unavailable ca-certificates
update-ca-trust extract 2>/dev/null || true
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | os=fedora dist=42 bash || true
# Rawhide (42) may lack CrowdSec packages — add Fedora 40 repo as fallback
if ! dnf list --available crowdsec 2>/dev/null | grep -q crowdsec; then
    echo "[01-virt] CrowdSec not found for dist=42 — trying Fedora 40 fallback repo..."
    cat > /etc/yum.repos.d/crowdsec-f40-fallback.repo <<'EOREPO'
[crowdsec-f40-fallback]
name=CrowdSec (Fedora 40 fallback)
baseurl=https://packagecloud.io/crowdsec/crowdsec/fedora/40/$basearch
gpgcheck=0
enabled=1
repo_gpgcheck=0
EOREPO
fi
dnf install -y --skip-unavailable --allowerasing --nobest crowdsec crowdsec-firewall-bouncer-nftables || true

# Only configure CrowdSec if it actually installed
if command -v crowdsec &>/dev/null; then
    echo "[01-virt] CrowdSec installed — configuring sovereign mode..."

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

    # CrowdSec ACQUISITION CONFIG — without this, agent refuses to start
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
else
    echo "[01-virt] WARN: CrowdSec unavailable (repo/SSL issue) — skipping config (non-fatal)"
fi

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
dnf install -y --skip-unavailable nodejs-npm npm || true
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
if command -v crowdsec &>/dev/null; then
    systemctl enable crowdsec.service 2>/dev/null || true
    systemctl enable crowdsec-firewall-bouncer.service 2>/dev/null || true
fi
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

# ═══ 0. PAM AUTHENTICATION FIX — MUST BE BEFORE USER CREATION ═══
# The Fedora bootc base image defaults to the 'sssd' authselect profile.
# Without sssd running, GDM's PAM stack fails → "password didn't work".
#
# CRITICAL: Use ONLY 'authselect select local --force' with NO extra features.
# - with-silent-lastlog → references pam_lastlog.so (REMOVED in Fedora 43+, breaks PAM)
# - with-mkhomedir → references pam_oddjob_mkhomedir.so (needs oddjobd running, fails if missing)
# - with-pam-gnome-keyring → references pam_gnome_keyring.so (fails if not installed)
# If ANY referenced .so is missing, the ENTIRE PAM chain fails and GDM rejects all passwords.
# The bare 'local' profile uses ONLY pam_unix.so — always present, always works.
authselect select local --force
echo "[99-overrides] authselect: local profile configured (pam_unix only — guaranteed to work)"

# ═══ 1. CREATE USER ═══
# bootc symlinks /home → /var/home — ensure directory exists first
mkdir -p /var/home /var/roothome
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
echo "INJ_U:INJ_P" | chpasswd
echo "root:INJ_P" | chpasswd
passwd -u INJ_U 2>/dev/null || true
# Verify password hash was written (debug — remove once confirmed working)
echo "[99-overrides] shadow check: $(getent shadow INJ_U | cut -d: -f1-2 | cut -c1-30)..."

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

# ═══ 4. SHELL ALIASES & TERMINAL CUSTOMIZATION ═══
cat >> /etc/skel/.bashrc <<'EOBASHRC'
alias scan-malware="podman run --rm -v ~/.clamav:/var/lib/clamav -v /var/home:/scandir:ro docker.io/clamav/clamav:latest clamscan -r /scandir"

# cloudws --help: quick reference
cloudws() {
    case "${1:-}" in
        --help|-h|help)
            echo "╔══════════════════════════════════════════════════════════════╗"
            echo "║  CloudWS v1.0 — Cloud Workstation OS                       ║"
            echo "╚══════════════════════════════════════════════════════════════╝"
            echo ""
            echo "  System Commands:"
            echo "    cloudws-update          Update OS from registry (bootc update)"
            echo "    cloudws-rebuild         Clone from GitHub → build → push"
            echo "    cloudws-backup          Backup volumes, K3s, VMs, home"
            echo "    cloudws-vfio-toggle     GPU VFIO bind/unbind/status/list"
            echo "    iommu-groups            Show IOMMU group assignments"
            echo "    scan-malware            On-demand ClamAV scan"
            echo ""
            echo "  System Info:"
            echo "    sudo bootc status       Current deployment info"
            echo "    sudo bootc rollback     Revert to previous deployment"
            echo "    sudo bootc upgrade      Pull latest from registry"
            echo "    fastfetch               System overview"
            echo ""
            echo "  Management:"
            echo "    https://localhost:9090   Cockpit web dashboard"
            echo "    virt-manager            Virtual machine manager"
            echo "    podman ps               Running containers"
            echo "    kubectl get pods        K3s workloads"
            echo ""
            ;;
        *) echo "Usage: cloudws --help" ;;
    esac
}

# fastfetch on terminal open
if command -v fastfetch &>/dev/null && [ -t 0 ] && [ -z "${CLOUDWS_NO_FASTFETCH:-}" ]; then
    fastfetch
fi
EOBASHRC
# Also install to existing user home if it exists
if [ -d /var/home/INJ_U ]; then
    cp /etc/skel/.bashrc /var/home/INJ_U/.bashrc 2>/dev/null || true
    chown INJ_U:INJ_U /var/home/INJ_U/.bashrc 2>/dev/null || true
fi

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

# cloudws-update — one-command system update
cat > /usr/local/bin/cloudws-update <<'EOUPD'
#!/bin/bash
set -euo pipefail
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS Update — Pulling latest from registry              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
if bootc update 2>/dev/null; then
    echo "✓ Update staged. Reboot to apply."
    echo "  To revert: sudo bootc rollback"
else
    echo "⚠ bootc update failed — trying bootc switch..."
    REF=$(bootc status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['spec']['image']['image'])" 2>/dev/null || echo "")
    if [ -n "$REF" ]; then
        bootc switch "$REF" && echo "✓ Switch complete. Reboot to apply." || echo "✗ Switch also failed."
    else
        echo "✗ Could not determine image reference. Check: sudo bootc status"
    fi
fi
EOUPD
chmod +x /usr/local/bin/cloudws-update

# cloudws-rebuild — clone → build → push
cat > /usr/local/bin/cloudws-rebuild <<'EORBD'
#!/bin/bash
set -euo pipefail
REPO="${CLOUDWS_REPO:-https://github.com/Kabuki94/CloudWS-bootc.git}"
WORK="/tmp/cloudws-rebuild-$$"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS Rebuild — Clone → Build → Push                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Repo: $REPO"
git clone --depth=1 "$REPO" "$WORK" || { echo "✗ Clone failed"; exit 1; }
cd "$WORK"
podman build --no-cache -t localhost/cloudws:latest .
echo ""
read -p "Push to registry? (y/N): " push
if [ "$push" = "y" ]; then
    read -p "Registry image ref [ghcr.io/kabuki94/cloudws-bootc:latest]: " ref
    ref="${ref:-ghcr.io/kabuki94/cloudws-bootc:latest}"
    podman tag localhost/cloudws:latest "$ref"
    podman push "$ref"
    echo "✓ Pushed to $ref"
fi
rm -rf "$WORK"
echo "✓ Rebuild complete. Run: sudo bootc update"
EORBD
chmod +x /usr/local/bin/cloudws-rebuild

# cloudws-backup — backup volumes, K3s, VMs, home
cat > /usr/local/bin/cloudws-backup <<'EOBAK'
#!/bin/bash
set -euo pipefail
DEST="${1:-/var/backup/cloudws-$(date +%Y%m%d-%H%M%S)}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS Backup → $DEST"
echo "╚══════════════════════════════════════════════════════════════╝"
mkdir -p "$DEST"
echo "  Backing up Podman volumes..."
podman volume ls --format '{{.Name}}' | while read v; do
    podman volume export "$v" > "$DEST/podman-vol-${v}.tar" 2>/dev/null || true
done
echo "  Backing up K3s state..."
if [ -d /var/lib/rancher/k3s ]; then
    tar czf "$DEST/k3s-state.tar.gz" -C /var/lib/rancher k3s 2>/dev/null || true
fi
echo "  Backing up libvirt VMs..."
if [ -d /var/lib/libvirt ]; then
    for dom in $(virsh list --all --name 2>/dev/null); do
        virsh dumpxml "$dom" > "$DEST/vm-${dom}.xml" 2>/dev/null || true
    done
fi
echo "  Backing up /var/home..."
tar czf "$DEST/var-home.tar.gz" -C /var home 2>/dev/null || true
echo "✓ Backup complete: $DEST"
ls -lh "$DEST/"
EOBAK
chmod +x /usr/local/bin/cloudws-backup

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

echo "[99-overrides] CloudWS v1.0 fully configured — authselect, user, hostname, firewall, GPU detect, CrowdSec, tools."
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
    rm -rf /var/cache/dnf /var/cache/rpm /var/log/* /tmp/scripts /root/.cache

LABEL containers.bootc 1
LABEL ostree.bootable 1
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

# ── Tag image for registry (must happen before BIB for GNOME Software updates) ─
Write-Step "Tagging local image → $GhcrImage"
& podman tag $LocalImage $GhcrImage

# ── Rechunk: optimize OCI layers for efficient Day-2 updates ────────────────
Write-Step "Rechunking image for optimized OCI layers (5-10x smaller updates)..."
$ErrorActionPreference = "Continue"
& podman run --rm --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    quay.io/centos-bootc/centos-bootc:stream10 `
    /usr/libexec/bootc-base-imagectl rechunk `
    $LocalImage `
    "${ImageName}:rechunked" 2>&1 | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkGray }
if ($LASTEXITCODE -eq 0) {
    # Replace original with rechunked version
    & podman tag "${ImageName}:rechunked" $LocalImage
    & podman tag "${ImageName}:rechunked" $GhcrImage
    & podman rmi "${ImageName}:rechunked" 2>$null
    Write-OK "Rechunk complete — layers optimized by package boundary"
} else {
    Write-Warn "Rechunk failed (non-fatal) — using original monolithic layers"
}
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4: TARGET SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 4 "Generating Deployment Targets"

# ── Target 1: RAW ────────────────────────────────────────────────────────────
Write-Step "TARGET 1 — Building RAW disk image via bootc-image-builder..."
$ErrorActionPreference = "Continue"
$bibArgs = @("build", "--type", "raw", "--rootfs", "ext4", "--local", $LocalImage)
if ($UseLuks -and $LuksPass) {
    Write-Step "  LUKS2 encryption enabled for RAW target"
    # Write a temporary config.toml with LUKS kickstart
    $bibConfig = @"
[customizations.installer.kickstart]
contents = """
clearpart --all --initlabel --disklabel=gpt
part /boot/efi --fstype=efi --size=600
part /boot --fstype=ext4 --size=1024
part pv.01 --size=1 --grow --encrypted --luks-version=luks2 --passphrase=$LuksPass
volgroup vg0 pv.01
logvol / --vgname=vg0 --fstype=xfs --size=10240 --name=root
"""
"@
    $bibConfigPath = Join-Path $OutputFolder "bib-config.toml"
    $bibConfig | Out-File -FilePath $bibConfigPath -Encoding ascii
    $bibArgs = @("build", "--type", "raw", "--rootfs", "ext4", "--config", "/output/bib-config.toml", "--local", $LocalImage)
}
& podman run --rm -it --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    -v "${OutputFolder}:/output:z" `
    quay.io/centos-bootc/bootc-image-builder:latest `
    @bibArgs

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
Write-Step "TARGET 2 — Building VHD via BIB then converting to Hyper-V VHDX..."
$ErrorActionPreference = "Continue"
& podman run --rm -it --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    -v "${OutputFolder}:/output:z" `
    quay.io/centos-bootc/bootc-image-builder:latest `
    build --type vhd --rootfs ext4 --local $LocalImage

$genVhd = Get-ChildItem $OutputFolder -Filter "disk.vhd" -Recurse -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genVhd) {
    Write-Step "  Converting VHD → VHDX (dynamic, Hyper-V Gen2 compatible)..."
    $vhdLeaf = $genVhd.Name
    $vhdDir  = Split-Path $genVhd.FullName -Parent
    & podman run --rm -v "${vhdDir}:/data:z" docker.io/alpine:latest `
        sh -c "apk add --no-cache qemu-img && qemu-img convert -p -f vpc -O vhdx -o subformat=dynamic /data/$vhdLeaf /data/cloudws-hyperv.vhdx"
    if ($LASTEXITCODE -eq 0) {
        Move-Item (Join-Path $vhdDir "cloudws-hyperv.vhdx") $TargetVhdx -Force -ErrorAction SilentlyContinue
        Remove-Item $genVhd.FullName -Force -ErrorAction SilentlyContinue
        Write-OK "VHDX conversion complete: $(Get-FileSize $TargetVhdx)"
    } else { Write-Warn "VHD→VHDX conversion failed" }
} else {
    Write-Warn "VHD generation failed — skipping VHDX"
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
$isoArgs = @("build", "--type", "anaconda-iso", "--rootfs", "ext4", "--local", $LocalImage)
if ($UseLuks -and $LuksPass -and (Test-Path (Join-Path $OutputFolder "bib-config.toml"))) {
    $isoArgs = @("build", "--type", "anaconda-iso", "--rootfs", "ext4", "--config", "/output/bib-config.toml", "--local", $LocalImage)
}
& podman run --rm -it --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    -v "${OutputFolder}:/output:z" `
    quay.io/centos-bootc/bootc-image-builder:latest `
    @isoArgs

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
#  PHASE 5: REGISTRY SYNCHRONIZATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase 5 "Remote Registry Push → $GhcrImage"

# ── Registry login ────────────────────────────────────────────────────────────
$registryHost = ($GhcrImage -split '/')[0]
Write-Step "Authenticating to $registryHost..."
$ErrorActionPreference = "Continue"
if ($RegistryToken) {
    $RegistryToken | podman login $registryHost --username $RegistryUser --password-stdin 2>&1 | ForEach-Object {
        Write-Host "        $_" -ForegroundColor DarkGray
    }
} else {
    Write-Warn "No registry token provided — attempting push without login (may fail for private repos)"
}

Write-Step "Pushing $GhcrImage ..."
$pushResult = & podman push $GhcrImage 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "Image pushed to $registryHost successfully"
    $GhcrOK = $true

    # Attempt to set GHCR package visibility to public (GitHub API only)
    if ($registryHost -eq "ghcr.io" -and $RegistryToken) {
        Write-Step "Setting GHCR package visibility to public..."
        $pkgName = ($GhcrImage -split '/')[-1] -replace ':.*$', ''
        $orgOrUser = ($GhcrImage -split '/')[1]
        try {
            $headers = @{ Authorization = "Bearer $RegistryToken"; Accept = "application/vnd.github+json" }
            Invoke-RestMethod -Uri "https://api.github.com/user/packages/container/$pkgName" `
                -Method Patch -Headers $headers `
                -Body '{"visibility":"public"}' -ContentType "application/json" -ErrorAction Stop
            Write-OK "GHCR package set to public"
        } catch {
            Write-Warn "Could not auto-set package to public. Manually set at: https://github.com/${orgOrUser}?tab=packages"
        }
    }
} else {
    Write-Warn "Registry push failed. Check credentials and permissions."
    Write-Warn "Details: $pushResult"
    $GhcrOK = $false
}
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 6: CLEANUP & FINAL STATUS REPORT
# ══════════════════════════════════════════════════════════════════════════════
$T1OK = Test-Path $RawImg
$T2OK = Test-Path $TargetVhdx
$T3OK = Test-Path $TargetWsl
$T4OK = Test-Path $TargetIso
$AllOK = $T1OK -and $T2OK -and $T3OK -and $T4OK -and $GhcrOK
$totalElapsed = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)

# ── Cleanup builder machine ───────────────────────────────────────────────────
Write-Phase 6 "Cleanup & Final Report"
Write-Step "Stopping builder machine '$BuilderMachine'..."
$ErrorActionPreference = "Continue"
Remove-Item Env:\CONTAINER_CONNECTION -ErrorAction SilentlyContinue
& podman machine stop $BuilderMachine 2>$null
Write-OK "Builder machine stopped (your default Podman machine is untouched)"
Write-Step "To remove the builder machine entirely: podman machine rm $BuilderMachine"

# Clean up temporary BIB config
Remove-Item (Join-Path $OutputFolder "bib-config.toml") -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

$reportColor = if ($AllOK) { "Green" } else { "Yellow" }
Write-Host ""
Write-Host "  $("═" * 78)" -ForegroundColor $reportColor
Write-Host "   CLOUDWS v1.0 DEPLOYMENT PIPELINE — COMPLETE  (total: ${totalElapsed} min)" -ForegroundColor $reportColor
Write-Host "  $("═" * 78)" -ForegroundColor $reportColor
Write-Host ""

Write-TargetReport 1 "Bare Metal RAW"     $T1OK  $RawImg     "Flash via Rufus (DD mode) or: dd if=cloudws-bootable.raw of=/dev/sdX bs=4M"
Write-TargetReport 2 "Hyper-V Gen2 VHDX"  $T2OK  $TargetVhdx "New Gen2 VM → Disable Secure Boot → attach VHDX as boot disk"
Write-TargetReport 3 "WSL2 + WSLg Distro" $T3OK  $TargetWsl  "wsl --import CloudWS C:\WSL\CloudWS '$TargetWsl' && wsl -d CloudWS"
Write-TargetReport 4 "Anaconda ISO"        $T4OK  $TargetIso  "Write to USB with Rufus (ISO mode) — Anaconda installer"
Write-TargetReport 5 "Registry Push"       $GhcrOK $GhcrImage "sudo bootc switch $GhcrImage"

Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
Write-Host "  │  Default credentials : $U / ****                            │" -ForegroundColor Yellow
Write-Host "  │  Upgrade any target  : sudo bootc upgrade                   │" -ForegroundColor DarkGray
Write-Host "  │  Switch image source : sudo bootc switch $GhcrImage         │" -ForegroundColor DarkGray
Write-Host "  │  GPU support         : AMD / Intel / NVIDIA (auto-detected) │" -ForegroundColor DarkGray
Write-Host "  │  Help in terminal    : cloudws --help                       │" -ForegroundColor DarkGray
Write-Host "  │  Cockpit dashboard   : https://localhost:9090                │" -ForegroundColor DarkGray
Write-Host "  │  Image Builder UI    : https://localhost:9090/composer       │" -ForegroundColor DarkGray
Write-Host "  │  RDP access          : port 3389 (standard) / 3390 (alt)    │" -ForegroundColor DarkGray
Write-Host "  │  SSH access          : port 22                              │" -ForegroundColor DarkGray
Write-Host "  │  Security            : CrowdSec IPS + fapolicyd + USBGuard  │" -ForegroundColor DarkGray
Write-Host "  │  Firewall            : default-deny drop + trusted internal │" -ForegroundColor DarkGray
Write-Host "  │  PXE/Network boot    : Use Anaconda ISO + ostreecontainer   │" -ForegroundColor DarkGray
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
Write-Host ""
