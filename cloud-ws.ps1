#Requires -RunAsAdministrator
<#
.SYNOPSIS  CloudWS v3.13 — Cloud Workstation OS Builder
.DESCRIPTION
    Architecture: XFS root (composefs, fills entire disk) + /var/home on same FS
    Desktop:      GNOME 50 Tokyo (Wayland-only) + Geist font + Flatpak-first app delivery
    RPM Layer:    Nautilus, Ptyxis, Wine/Steam/Proton/Lutris, KVM/QEMU/Libvirt, Podman, XRDP
    Flatpak:      Epiphany + Podman Desktop + Bottles + VSCodium + Extension Manager + Logs — PRE-INSTALLED, USER-REMOVABLE
    Gaming:       Gamescope SteamOS-mode fullscreen session selectable at GDM login
    Hardware:     AMD RDNA2 iGPU + NVIDIA RTX 4090 (akmod) + driverctl VFIO toggle
    Security:     Waydroid, CrowdSec IPS (sovereign/offline), Fapolicyd, USBGuard, Firewalld Lockdown
    HA/Cluster:   K3s, Pacemaker/Corosync, Longhorn, Velero, HAProxy, Keepalived
    Targets:      RAW disk, Hyper-V VHDX, WSL2 tarball, Anaconda ISO, Live USB ISO, local OCI
    Self-repl:    cloudws-rebuild clones from GitHub, builds, pushes — full CI/CD from any running instance
#>
$ErrorActionPreference="Stop";Set-StrictMode -Version Latest
$I="cloudws:latest";$O="$PWD\cloudws-deploy-out";$B="$env:TEMP\cws-build"
$R_Img="$O\cloudws-bootable.raw";$T_V="$O\cloudws-hyperv.vhdx";$T_W="$O\cloudws-wsl.tar";$T_I="$O\cloudws-installer.iso";$T_L="$O\cloudws-live.iso"

# ══════════════════════════════════════════════════════════════════════════════
#  TIMEOUT READ HELPER (defaults after 5 minutes)
# ══════════════════════════════════════════════════════════════════════════════
function Read-TimedHost($prompt, $default = 'n', $seconds = 300) {
    Write-Host "$prompt " -NoNewline -ForegroundColor Yellow
    Write-Host "(auto '$default' in ${seconds}s): " -NoNewline -ForegroundColor DarkGray
    $end = (Get-Date).AddSeconds($seconds)
    while (-not [Console]::KeyAvailable -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 200 }
    if ([Console]::KeyAvailable) { $key = Read-Host; if ($key -ne '') { return $key } }
    Write-Host $default; return $default
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0: ALL QUESTIONS UPFRONT
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         CloudWS v3.13 — Build Configuration                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── OS Credentials (defaults: cloudws/cloudws for pre-built images) ──
Write-Host "  Defaults: cloudws / cloudws (press Enter to accept)" -ForegroundColor Gray
$U = Read-Host "CloudWS username [cloudws]"
if (-not $U) { $U = "cloudws" }
$pInput = Read-Host "CloudWS password [cloudws]" -AsSecureString
$pPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pInput))
$P = if ($pPlain) { $pPlain } else { "cloudws" }

# ── Build Targets ──
Write-Host "`n═══ Build Targets ═══" -ForegroundColor Yellow
Write-Host "  OCI image is always built. Select additional targets:" -ForegroundColor Gray
$buildRaw  = Read-TimedHost "  Build RAW disk image? (y/n)" 'y'
$buildVhdx = if ($buildRaw -eq 'y') { Read-TimedHost "  Convert RAW → VHDX (Hyper-V)? (y/n)" 'y' } else { 'n' }
$buildWsl  = Read-TimedHost "  Export WSL2 + WSLg tarball? (y/n)" 'y'
$buildIso  = Read-TimedHost "  Build Anaconda installer ISO? (y/n)" 'y'
$buildLive = Read-TimedHost "  Build Live USB ISO? (y/n)" 'n'

# ── LUKS Encryption (RAW/ISO only) ──
$enableLuks = 'n'
$luksPass = ''
if ($buildRaw -eq 'y' -or $buildIso -eq 'y') {
    Write-Host "`n═══ Disk Encryption ═══" -ForegroundColor Yellow
    Write-Host "  LUKS2 encryption applies to RAW disk + ISO targets only." -ForegroundColor Gray
    $enableLuks = Read-TimedHost "  Enable LUKS2 encryption? (y/n)" 'n'
    if ($enableLuks -eq 'y') {
        $lp1 = Read-Host "  LUKS passphrase" -AsSecureString
        $luksPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($lp1))
    }
}

# ── Deployment Options ──
Write-Host "`n═══ Post-Build Deployment ═══" -ForegroundColor Yellow
$deployWsl = if ($buildWsl -eq 'y') { Read-TimedHost "  Deploy to WSL2 after build? (y/n)" 'n' } else { 'n' }
$deployWslDefault = if ($deployWsl -eq 'y') { Read-TimedHost "    Set as default WSL distro? (y/n)" 'n' } else { 'n' }
$deployHyperV = if ($buildVhdx -eq 'y') { Read-TimedHost "  Create Hyper-V VM after build? (y/n)" 'n' } else { 'n' }
$startVm = if ($deployHyperV -eq 'y') { Read-TimedHost "    Start VM immediately? (y/n)" 'n' } else { 'n' }

# ── GHCR (absolute last step) ──
Write-Host "`n═══ GitHub Container Registry ═══" -ForegroundColor Yellow
$GhcrImage = "ghcr.io/kabuki94/cloudws-bootc"
Write-Host "  Repository: $GhcrImage" -ForegroundColor White
$ghcrReady = $false

# Check if credentials were passed from push-to-github.ps1
if ($env:CLOUDWS_GHCR_USER -and $env:CLOUDWS_GHCR_TOKEN) {
    $ghUser = $env:CLOUDWS_GHCR_USER
    $ghTokenPlain = $env:CLOUDWS_GHCR_TOKEN
    $ghcrReady = $true
    $pushToGhcr = 'y'
    Write-Host "  ✓ GHCR credentials inherited from push-to-github" -ForegroundColor Green
    # Clean up env vars
    $env:CLOUDWS_GHCR_USER = $null
    $env:CLOUDWS_GHCR_TOKEN = $null
} else {
    $pushToGhcr = Read-TimedHost "  Push to GHCR after everything? (y/n)" 'n'
    if ($pushToGhcr -eq 'y') {
        Write-Host "  PAT needs scopes: write:packages, read:packages" -ForegroundColor Gray
        Write-Host "  Create at: https://github.com/settings/tokens/new" -ForegroundColor Cyan
        $ghUser = Read-Host "  GitHub username"
        $ghToken = Read-Host "  GitHub PAT" -AsSecureString
        $ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))
        $ghcrReady = $true
    }
}

# ── Summary ──
Write-Host "`n═══ Build Plan ═══" -ForegroundColor Cyan
Write-Host "  User:     $U" -ForegroundColor White
Write-Host "  Targets:  OCI$(if($buildRaw -eq 'y'){' + RAW'})$(if($buildVhdx -eq 'y'){' + VHDX'})$(if($buildWsl -eq 'y'){' + WSL'})$(if($buildIso -eq 'y'){' + ISO'})$(if($buildLive -eq 'y'){' + LIVE'})" -ForegroundColor White
Write-Host "  LUKS:     $(if($enableLuks -eq 'y'){'Enabled (RAW/ISO)'}else{'Disabled'})" -ForegroundColor White
Write-Host "  Deploy:   $(if($deployWsl -eq 'y'){'WSL '}else{''})$(if($deployHyperV -eq 'y'){'Hyper-V '}else{''})$(if($deployWsl -ne 'y' -and $deployHyperV -ne 'y'){'None'})" -ForegroundColor White
Write-Host "  Updates:  $GhcrImage`:latest (bootc update target)" -ForegroundColor White
Write-Host "  GHCR:     $(if($ghcrReady){'Yes (last step)'}else{'No'})" -ForegroundColor White
Write-Host ""
Write-Host "  All questions answered. Build is now fully unattended." -ForegroundColor Green
Write-Host "  ─────────────────────────────────────────────────────" -ForegroundColor DarkGray
Start-Sleep 3

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1: PODMAN MACHINE
# ══════════════════════════════════════════════════════════════════════════════
if(!(Test-Path $O)){md $O -Force|Out-Null}
$c=(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors;$r=[math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1MB)
wsl --shutdown 2>$null;Start-Sleep 2
if((podman machine inspect podman-machine-default 2>&1)-match "not found"){podman machine init --rootful --cpus $c --memory $r --disk-size 150}else{podman machine stop 2>$null;Start-Sleep 2;podman machine set --cpus $c --memory $r 2>$null}
podman machine start;if($LASTEXITCODE -ne 0){throw "Podman fail"}

if ($ghcrReady) {
    Write-Host "Logging into GHCR..." -ForegroundColor Cyan
    $ghTokenPlain | podman login ghcr.io -u $ghUser --password-stdin
    if ($LASTEXITCODE -eq 0) { Write-Host "  ✓ Logged into ghcr.io" -ForegroundColor Green }
    else { Write-Host "  ✗ GHCR login failed — will skip push" -ForegroundColor Yellow; $ghcrReady = $false }
}

if(Test-Path $B){rm -Recurse -Force $B};"base","desktop","hardware","virtualization","system"|%{md "$B\build_files\$_" -Force|Out-Null}

# ════════════════════════════════════════════════════════════════════
#  01-repos.sh — RPMFusion + Workstation repos
# ════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-rawhide.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-rawhide.noarch.rpm
dnf install -y fedora-workstation-repositories dnf-plugins-core
echo "[01-repos] RPMFusion + Workstation repos enabled."
'@|Out-File "$B\build_files\base\01-repos.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  02-kernel.sh — Latest kernel + headers + NTSync
# ════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail
dnf upgrade -y --refresh --allowerasing --nobest kernel kernel-core kernel-modules
dnf install -y --allowerasing --nobest \
    kernel-devel kernel-headers kernel-modules-extra kernel-tools \
    glibc-headers glibc-devel python3
curl -sL https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/ntsync.h \
    -o /usr/include/linux/ntsync.h 2>/dev/null || true
echo "[02-kernel] Kernel secured: $(ls /lib/modules|sort -V|tail -1)"
'@|Out-File "$B\build_files\base\02-kernel.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  01-gnome.sh — GNOME 50 Desktop + Flatpak bake + Gamescope session
# ════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail
mkdir -p /var/roothome

# ═══════════════════════════════════════════════════════════════════════
#  GNOME CORE RPM LAYER — STRICT (build CRASHES if these fail)
#  These are the guaranteed Fedora Rawhide packages.
# ═══════════════════════════════════════════════════════════════════════
dnf install -y --allowerasing --nobest \
    gdm gnome-shell gnome-session gnome-settings-daemon gnome-control-center \
    mutter gjs gnome-keyring polkit \
    nautilus ptyxis \
    gnome-software \
    gnome-shell-extension-appindicator gnome-shell-extension-dash-to-dock \
    gvfs gvfs-smb gvfs-mtp gvfs-goa gvfs-afc \
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal \
    xdg-user-dirs xdg-utils \
    NetworkManager-wifi NetworkManager-openvpn-gnome \
    flatpak adwaita-cursor-theme adwaita-icon-theme \
    gnome-backgrounds gsettings-desktop-schemas \
    upower gnome-bluetooth bluez bluez-tools \
    gnome-remote-desktop gnome-color-manager colord \
    gnome-disk-utility gnome-system-monitor \
    git nano fastfetch wayland-utils glibc-langpack-en \
    pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
    vulkan-validation-layers mesa-libEGL mesa-libgbm \
    qt5-qtwayland qt6-qtwayland \
    xrdp xorgxrdp xorg-x11-server-Xorg

# ═══ OPTIONAL RPM PACKAGES (skip if not in Rawhide yet) ═══
# Qt theme bridge, ostree backend, tiling — these packages rotate in/out of Rawhide
dnf install -y --skip-unavailable --skip-broken --allowerasing --nobest \
    gnome-software-rpm-ostree appstream-data \
    gnome-shell-extension-tiling-assistant \
    gnome-shell-extension-caffeine \
    adwaita-qt5 adwaita-qt6 \
    qadwaitadecorations-qt5 qadwaitadecorations-qt6 \
    qgnomeplatform-qt5 qgnomeplatform-qt6 \
    || echo "[WARN] Some optional desktop packages unavailable in Rawhide — continuing."

# ═══ FAULT-TOLERANT MULTIMEDIA (RPMFusion desync protection) ═══
dnf install -y --skip-unavailable --skip-broken --allowerasing --nobest \
    ffmpeg gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free \
    gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugins-ugly-free \
    gstreamer1-libav gstreamer1-vaapi libavcodec-freeworld \
    || echo "[WARN] Some codecs unavailable — RPMFusion Rawhide sync delay."

# ═══ GEIST FONT ═══
git clone --depth=1 https://github.com/vercel/geist-font.git /tmp/geist
mkdir -p /usr/share/fonts/geist
find /tmp/geist -name "*.ttf" -exec cp {} /usr/share/fonts/geist/ \;
fc-cache -f; rm -rf /tmp/geist

# ═══ BIBATA CURSOR THEME (Modern Classic — dark native) ═══
BIBATA_VER="2.0.7"
curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz" -o /tmp/bibata.tar.xz
mkdir -p /usr/share/icons
tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/
rm -f /tmp/bibata.tar.xz
# Set as system default cursor
update-alternatives --install /usr/share/icons/default/index.theme x-cursor-theme \
    /usr/share/icons/Bibata-Modern-Classic/cursor.theme 90 2>/dev/null || true
echo "[01-gnome] Bibata Modern Classic cursor installed."

# ═══ GAMESCOPE STEAM SESSION (selectable at GDM login) ═══
# Creates a full SteamOS-mode Gamescope session visible in GDM session picker
mkdir -p /usr/share/wayland-sessions /usr/bin

cat > /usr/bin/gamescope-session-steam <<'EOGSS'
#!/bin/bash
# CloudWS Gamescope Steam Session — launched by GDM
export HOMETEST_DESKTOP_USER="${USER}"
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
export STEAM_USE_MANGOAPP=1
export MANGOHUD=1
export ENABLE_GAMESCOPE_WSI=1
export STEAM_GAMESCOPE_HAS_TEARING_SUPPORT=1
export STEAM_GAMESCOPE_COLOR_MANAGED=1

# Detect primary display resolution
if command -v wlr-randr &>/dev/null; then
    RES=$(wlr-randr 2>/dev/null | grep -oP '\d+x\d+' | head -1)
elif [ -d /sys/class/drm ]; then
    for conn in /sys/class/drm/card*/card*-*; do
        [ "$(cat "$conn/status" 2>/dev/null)" = "connected" ] && \
            RES=$(head -1 "$conn/modes" 2>/dev/null) && break
    done
fi
W="${RES%%x*}"; H="${RES##*x}"
W="${W:-1920}"; H="${H:-1080}"

exec gamescope -e \
    -W "$W" -H "$H" \
    -w "$W" -h "$H" \
    --adaptive-sync \
    --xwayland-count 2 \
    --default-touch-mode 4 \
    --hide-cursor-delay 3000 \
    --fade-out-duration 200 \
    -- steam -gamepadui -steamos3 -steampal
EOGSS
chmod +x /usr/bin/gamescope-session-steam

# Dummy scripts Steam expects on SteamOS
for script in steamos-update jupiter-biosupdate steamos-select-branch; do
    cat > /usr/bin/$script <<EODUMMY
#!/bin/bash
# CloudWS stub — $script
exit 0
EODUMMY
    chmod +x /usr/bin/$script
done

cat > /usr/bin/steamos-session-select <<'EOSESS'
#!/bin/bash
# CloudWS session switcher — returns to GDM
case "${1:-}" in
    desktop|gnome) ;;
    *) ;;
esac
# Signal Steam to exit cleanly, GDM will present the login screen
steam -shutdown 2>/dev/null || true
sleep 2
loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null || true
EOSESS
chmod +x /usr/bin/steamos-session-select

# Polkit helpers Steam expects
mkdir -p /usr/bin/steamos-polkit-helpers
for h in steamos-update steamos-set-timezone steamos-select-branch; do
    ln -sf /usr/bin/$h /usr/bin/steamos-polkit-helpers/$h
done

cat > /usr/share/wayland-sessions/steam.desktop <<'EOSD'
[Desktop Entry]
Encoding=UTF-8
Name=Steam (Gamescope)
Comment=SteamOS-mode fullscreen gaming session
Exec=/usr/bin/gamescope-session-steam
Type=Application
DesktopNames=gamescope
EOSD

# ═══ COCKPIT WEBAPP ═══
mkdir -p /usr/share/applications /etc/cockpit
cat > /usr/share/applications/cloudws-cockpit.desktop <<'EODESKTOP'
[Desktop Entry]
Name=CloudWS Cockpit
Comment=System Administration Dashboard
Exec=xdg-open http://localhost:9090
Icon=cockpit
Terminal=false
Type=Application
Categories=System;
StartupNotify=true
EODESKTOP
cat > /etc/cockpit/cockpit.conf <<'EOCOCKPIT'
[WebService]
AllowUnencrypted = true
LoginTitle = CloudWS
MaxStartups = 10
AllowMultiHost = true
ProtocolHeader = X-Forwarded-Proto
EOCOCKPIT

# Cockpit must listen on ALL interfaces for host→VM access
mkdir -p /etc/systemd/system/cockpit.socket.d
cat > /etc/systemd/system/cockpit.socket.d/listen.conf <<'EOCKSOCK'
[Socket]
ListenStream=
ListenStream=9090
FreeBind=yes
EOCKSOCK

systemctl enable gdm.service NetworkManager.service xrdp.service
systemctl set-default graphical.target

# ═══ GDM WAYLAND-NATIVE CONFIGURATION ═══
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'EOGDM'
[daemon]
WaylandEnable=true
AutomaticLoginEnable=false

[security]

[xdmcp]

[chooser]

[debug]
EOGDM

# Ensure GDM uses Wayland even without NVIDIA (VM environments)
# GDM checks for /etc/udev/rules.d/61-gdm.rules to decide Wayland eligibility
# Remove any rule that forces X11 when NVIDIA is detected
rm -f /usr/lib/udev/rules.d/61-gdm.rules 2>/dev/null || true

# ═══ ENVIRONMENT ═══
mkdir -p /etc/environment.d /etc/gtk-3.0 /etc/gtk-4.0

cat > /etc/environment.d/50-cloudws.conf <<'EOENV'
QT_QPA_PLATFORMTHEME=gnome
QT_WAYLAND_DECORATION=adwaita
ADW_DISABLE_PORTAL=0
ELECTRON_OZONE_PLATFORM_HINT=auto
XDG_CURRENT_DESKTOP=GNOME
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24
EOENV

cat > /etc/gtk-3.0/settings.ini <<'EOGTK3'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-font-name=Geist 11
EOGTK3

cat > /etc/gtk-4.0/settings.ini <<'EOGTK4'
[Settings]
gtk-hint-font-metrics=1
EOGTK4

mkdir -p /usr/share/xdg-desktop-portal
cat > /usr/share/xdg-desktop-portal/gnome-portals.conf <<'EOPORTAL'
[preferred]
default=gnome;gtk;
EOPORTAL

# ═══ FLATPAK — FULL BUILD-TIME INSTALL (offline-ready, user-removable) ═══
# Apps install into /var/lib/flatpak during build. bootc seeds /var on first
# deploy, so they're available day one — fully offline, fully removable.
# Runtimes are auto-pulled as dependencies — do NOT install them separately.
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --if-not-exists gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo

# CloudWS core Flatpak apps — all pre-installed, all user-removable
FLATPAK_APPS=(
    org.gnome.Epiphany
    org.gnome.Logs
    io.podman_desktop.PodmanDesktop
    com.usebottles.bottles
    com.mattjakeman.ExtensionManager
    com.vscodium.codium
)

for app in "${FLATPAK_APPS[@]}"; do
    echo "[01-gnome] Installing Flatpak: $app"
    flatpak install --system -y --noninteractive gnome-nightly "$app" 2>/dev/null \
    || flatpak install --system -y --noninteractive flathub "$app" 2>/dev/null \
    || echo "[WARN] Flatpak $app unavailable — skipping."
done

# Global overrides (Wayland, theme integration)
flatpak override --system --env=ELECTRON_OZONE_PLATFORM_HINT=auto 2>/dev/null || true
flatpak override --system --env=ADW_DISABLE_PORTAL=0 2>/dev/null || true
flatpak override --system --env=XCURSOR_THEME=Bibata-Modern-Classic 2>/dev/null || true
flatpak override --system --env=XCURSOR_SIZE=24 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-3.0:ro 2>/dev/null || true
flatpak override --system --filesystem=xdg-config/gtk-4.0:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/themes:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/icons:ro 2>/dev/null || true
flatpak override --system --filesystem=/usr/share/fonts:ro 2>/dev/null || true

# Clean unused flatpak refs + reduce image bloat
flatpak uninstall --system --unused -y 2>/dev/null || true
rm -rf /var/tmp/flatpak-cache-* 2>/dev/null || true

echo "[01-gnome] Flatpaks installed: $(flatpak list --system --app --columns=application | wc -l) apps"

# ═══ DCONF: Theme + Dock + Folders ═══
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d /etc/dconf/db/local.d/locks
echo -e "user-db:user\nsystem-db:local" > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/01-cloudws <<'EOF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
accent-color='blue'
icon-theme='Adwaita'
cursor-theme='Bibata-Modern-Classic'
font-name='Geist 11'
document-font-name='Geist 11'
monospace-font-name='Geist Mono 10'
enable-animations=true
[org/gnome/desktop/wm/preferences]
theme='Adwaita'
titlebar-font='Geist Bold 11'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gnome/blobs-l.svg'
picture-uri-dark='file:///usr/share/backgrounds/gnome/blobs-d.svg'
picture-options='zoom'
primary-color='#241f31'
[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/blobs-d.svg'
primary-color='#241f31'
[org/gnome/desktop/sound]
theme-name='freedesktop'
[org/gnome/shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'appindicatorsupport@rgcjonas.gmail.com', 'tiling-assistant@leleat-on-github', 'caffeine@patapon.info']
favorite-apps=['org.gnome.Epiphany.desktop', 'org.gnome.Ptyxis.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Software.desktop', 'cloudws-cockpit.desktop']
[org/gnome/shell/extensions/dash-to-dock]
dock-fixed=true
dock-position='BOTTOM'
dash-max-icon-size=48
transparency-mode='DYNAMIC'
running-indicator-style='DOTS'
apply-custom-theme=true
[org/gnome/desktop/app-folders]
folder-children=['Wine', 'Gaming', 'Virt', 'Utilities', 'Media']
[org/gnome/desktop/app-folders/folders/Wine]
name='Wine'
categories=['Wine']
apps=['wine.desktop', 'wine-browsedrive.desktop', 'wine-notepad.desktop', 'wine-regedit.desktop', 'wine-uninstaller.desktop', 'wine-winecfg.desktop', 'wine-wineboot.desktop', 'wine-winefile.desktop', 'wine-winehelp.desktop', 'wine-oleview.desktop', 'wine-wordpad.desktop', 'wine-winemine.desktop', 'winetricks.desktop', 'wine-mime-msi.desktop', 'wine-extension-txt.desktop', 'wine-help.desktop', 'Wine Help.desktop', 'wine64.desktop', 'wine64-preloader.desktop', 'net.winehq.Wine.desktop', 'net.winehq.Wine.Help.desktop', 'wine-winhelp.desktop', 'wine-winhlp32.desktop']
[org/gnome/desktop/app-folders/folders/Gaming]
name='Gaming'
apps=['steam.desktop', 'com.valvesoftware.Steam.desktop', 'net.lutris.Lutris.desktop', 'lutris.desktop', 'dosbox-staging.desktop', 'io.github.dosbox-staging.desktop', 'org.dosbox-staging.dosbox-staging.desktop', 'com.usebottles.bottles.desktop', 'gamescope.desktop', 'gamemode.desktop', 'gamemoderun.desktop']
[org/gnome/desktop/app-folders/folders/Virt]
name='Virtualization'
apps=['io.podman_desktop.PodmanDesktop.desktop', 'virt-manager.desktop', 'org.gnome.Boxes.desktop', 'qemu.desktop', 'cloudws-cockpit.desktop', 'Waydroid.desktop', 'waydroid.desktop', 'gamt.desktop', 'remote-viewer.desktop']
[org/gnome/desktop/app-folders/folders/Utilities]
name='Utilities'
apps=['org.gnome.Settings.desktop', 'org.gnome.SystemMonitor.desktop', 'org.gnome.Resources.desktop', 'org.gnome.DiskUtility.desktop', 'org.gnome.baobab.desktop', 'com.mattjakeman.ExtensionManager.desktop', 'org.gnome.Connections.desktop', 'org.gnome.Logs.desktop', 'nvidia-settings.desktop', 'nvtop.desktop', 'btop.desktop', 'virt-top.desktop', 'org.fedoraproject.MediaWriter.desktop', 'mediawriter.desktop', 'malcontent-control.desktop', 'org.freedesktop.MalcontentControl.desktop', 'org.gnome.ParentalControls.desktop']
[org/gnome/desktop/app-folders/folders/Media]
name='Media'
apps=['org.gnome.Music.desktop', 'org.gnome.Showtime.desktop', 'org.gnome.Snapshot.desktop', 'org.gnome.Loupe.desktop', 'org.gnome.Decibels.desktop', 'simple-scan.desktop', 'org.gnome.SoundRecorder.desktop']
EOF
cat > /etc/dconf/db/local.d/locks/cloudws <<'EOF'
/org/gnome/desktop/app-folders/folder-children
/org/gnome/shell/favorite-apps
EOF
dconf update
echo "[01-gnome] GNOME 50 + Gamescope Steam Session + Flatpaks initialized."
'@|Out-File "$B\build_files\desktop\01-gnome.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  01-hardware.sh — AMD iGPU + NVIDIA 4090 + driverctl VFIO toggle
# ════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail
dnf install -y --skip-unavailable --allowerasing --nobest \
    mesa-vulkan-drivers mesa-dri-drivers mesa-va-drivers mesa-vdpau-drivers \
    vulkan-loader vulkan-tools libva-utils linux-firmware amd-ucode microcode_ctl \
    rocm-opencl rocm-hip akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-container-toolkit driverctl
akmods --force --kernels "$(ls /lib/modules|sort -V|tail -n 1)" || true
nvidia-ctk cdi generate --output=/etc/cdi/nvidia.json 2>/dev/null || true
mkdir -p /etc/modprobe.d /etc/modules-load.d
cat > /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_EnableGpuFirmware=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nouveau.conf
echo -e "ntsync\nvfio-pci" > /etc/modules-load.d/cloudws.conf

cat > /usr/local/bin/cloudws-vfio-toggle <<'EOVFIO'
#!/bin/bash
set -euo pipefail
if [ $# -eq 0 ]; then
    echo "CloudWS VFIO GPU Toggle"
    echo "Usage:  cloudws-vfio-toggle <PCI_ID> [bind|unbind|status]"
    echo "        cloudws-vfio-toggle list"
    exit 0
fi
if [ "$1" = "list" ]; then
    echo -e "\033[1;36m═══ GPU Devices ═══\033[0m"
    lspci -nnk | grep -A2 -E "VGA|3D"
    echo -e "\n\033[1;36m═══ IOMMU Groups ═══\033[0m"
    shopt -s nullglob
    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d 2>/dev/null|sort -V); do
        echo -e "\033[1;34mGroup ${g##*/}:\033[0m"
        for d in $g/devices/*; do echo "  $(lspci -nns ${d##*/})"; done
    done; exit 0
fi
PCI_ID="$1"; ACTION="${2:-toggle}"
CUR=$(driverctl -b pci display "$PCI_ID" 2>/dev/null || echo "none")
case "$ACTION" in
    bind)   driverctl set-override "$PCI_ID" vfio-pci; echo "$PCI_ID → vfio-pci";;
    unbind) driverctl unset-override "$PCI_ID"; echo "$PCI_ID → restored";;
    status) echo "$PCI_ID → $CUR";;
    toggle) if [[ "$CUR" == *"vfio-pci"* ]]; then driverctl unset-override "$PCI_ID"; echo "$PCI_ID → restored"
            else driverctl set-override "$PCI_ID" vfio-pci; echo "$PCI_ID → vfio-pci"; fi;;
esac
EOVFIO
chmod +x /usr/local/bin/cloudws-vfio-toggle
echo "[01-hardware] AMD+NVIDIA+driverctl VFIO toggle installed."
'@|Out-File "$B\build_files\hardware\01-hardware.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  01-virt.sh — Full KVM/Podman/Gaming/Cockpit/HA/Security + LG B7
# ════════════════════════════════════════════════════════════════════
@'
#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
#  SINGLE ATOMIC INSTALL — All virtualization, container, gaming,
#  cockpit, HA, storage, networking, security, and tooling packages.
#  Minimizes dead files by installing everything in one transaction.
# ═══════════════════════════════════════════════════════════════════════
dnf install -y --skip-unavailable --allowerasing --nobest \
    qemu-kvm qemu-img qemu-user-static \
    libvirt libvirt-daemon libvirt-daemon-kvm libvirt-daemon-qemu \
    libvirt-client libvirt-nss libvirt-dbus \
    virt-install virt-manager virt-viewer spice-gtk virt-top \
    edk2-ovmf edk2-qosb swtpm swtpm-tools dnsmasq mdevctl \
    libguestfs libguestfs-tools guestfs-tools nbdkit libnbd \
    lm_sensors btop nvtop intel-gpu-tools \
    shim-x64 mokutil sbsigntools pesign efitools \
    podman podman-compose podman-remote kubernetes-client docker-compose \
    buildah skopeo toolbox distrobox \
    bootc bootc-image-builder osbuild osbuild-composer osbuild-selinux composer-cli rpm-ostree \
    crun netavark aardvark-dns slirp4netns composefs \
    cockpit cockpit-ws cockpit-bridge \
    cockpit-system cockpit-machines cockpit-podman cockpit-ostree cockpit-storaged \
    cockpit-networkmanager cockpit-selinux cockpit-image-builder \
    pcp cockpit-pcp pcp-zeroconf \
    gamemode mangohud gamescope wine winetricks lutris dosbox-staging steam steam-devices \
    waydroid \
    hyperv-daemons qemu-guest-agent open-vm-tools spice-vdagent \
    cifs-utils virtiofsd lvm2 mdadm btrfs-progs samba nfs-utils openssh-server tailscale \
    git jq make curl wget polkit udisks2 clevis oddjob-mkhomedir \
    nut nut-client \
    cloud-init rsync tmux screen tree \
    socat nmap-ncat tcpdump iptables-nft conntrack-tools \
    nvme-cli device-mapper-multipath sg3_utils \
    chrony firewalld zram-generator \
    fapolicyd usbguard \
    policycoreutils-python-utils checkpolicy \
    cdrkit xorriso genisoimage isomd5sum mediawriter squashfs-tools erofs-utils dracut-live \
    python3 python3-devel python3-pip python3-setuptools python3-wheel python3-virtualenv python3-venv \
    python3-requests python3-yaml python3-toml python3-jsonschema python3-pillow python3-tqdm \
    python3-rich python3-click python3-pytest python3-black python3-mypy python3-ruff

# ═══ HIGH AVAILABILITY / CLUSTERING ═══
dnf install -y --skip-unavailable --allowerasing --nobest \
    corosync pacemaker pcs fence-agents-all resource-agents \
    keepalived haproxy \
    sanlock libvirt-lock-sanlock \
    iscsi-initiator-utils targetcli ceph-common \
    glusterfs glusterfs-server glusterfs-fuse glusterfs-cli \
    etcd helm wireguard-tools

# ═══ CROWDSEC IPS — SOVEREIGN MODE (no outbound telemetry) ═══
echo "[01-virt] Installing CrowdSec IPS (sovereign/offline mode)..."
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.rpm.sh | os=fedora dist=40 bash
dnf install -y --skip-unavailable --allowerasing --nobest crowdsec crowdsec-firewall-bouncer-nftables

# Enforce sovereign operation — disable ALL outbound reporting
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

# Also disable the online API enrollment entirely
mkdir -p /etc/crowdsec/local_api_credentials.yaml.d
cat > /etc/crowdsec/local_api_credentials.yaml.d/sovereign.yaml <<'EOSOV'
# Sovereign override — no CAPI registration
url: http://127.0.0.1:8080/
login: ""
password: ""
EOSOV

mkdir -p /etc/systemd/system/crowdsec-hubupdate.service.d
cat > /etc/systemd/system/crowdsec-hubupdate.service.d/override.conf <<'EOF'
[Unit]
After=network-online.target
Wants=network-online.target
EOF

# ═══ TUNED POWER MANAGEMENT (replaces power-profiles-daemon) ═══
dnf remove -y power-profiles-daemon 2>/dev/null || true
dnf install -y --allowerasing --nobest \
    tuned tuned-ppd tuned-utils tuned-profiles-cpu-partitioning tuned-profiles-realtime

# ═══ K3s LIGHTWEIGHT KUBERNETES ═══
echo "[01-virt] Installing K3s..."
curl -sfL https://get.k3s.io -o /usr/local/bin/k3s-install.sh
chmod +x /usr/local/bin/k3s-install.sh
curl -sfL "https://github.com/k3s-io/k3s/releases/latest/download/k3s" -o /usr/local/bin/k3s 2>/dev/null || true
chmod +x /usr/local/bin/k3s 2>/dev/null || true
[ -f /usr/local/bin/k3s ] && {
    ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
    ln -sf /usr/local/bin/k3s /usr/local/bin/crictl 2>/dev/null || true
    ln -sf /usr/local/bin/k3s /usr/local/bin/ctr 2>/dev/null || true
}
cat > /usr/lib/systemd/system/k3s.service <<'K3SVC'
[Unit]
Description=Lightweight Kubernetes
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStartPre=/bin/sh -c '! /usr/bin/systemctl is-enabled --quiet nm-wait-online 2>/dev/null || /usr/bin/systemctl start nm-wait-online'
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

# ═══ SERVICE ENABLEMENT ═══
mkdir -p /etc/systemd/system-preset
cat > /etc/systemd/system-preset/50-cloudws.preset <<'EOF'
enable libvirtd.service
enable cockpit.socket
enable podman.socket
enable osbuild-composer.socket
enable sshd.service
enable tuned.service
enable pmcd.service
enable pmlogger.service
enable pmproxy.service
enable firewalld.service
enable fapolicyd.service
enable usbguard.service
enable crowdsec.service
enable crowdsec-firewall-bouncer.service
enable waydroid-container.service
EOF
systemctl enable libvirtd.service virtqemud.socket virtnetworkd.socket virtstoraged.socket
systemctl enable cockpit.socket podman.socket osbuild-composer.socket sshd.service tuned.service pmcd.service pmlogger.service pmproxy.service oddjobd.service
systemctl enable podman-auto-update.timer podman-restart.service qemu-guest-agent.service hypervvssd.service hypervkvpd.service smb.service nmb.service nfs-server.service tailscaled.service 2>/dev/null || true
systemctl enable bluetooth.service xrdp.service xrdp-sesman.service 2>/dev/null || true
systemctl enable pcsd.service cloud-init.service cloud-init-local.service cloud-config.service cloud-final.service multipathd.service chronyd.service 2>/dev/null || true
tuned-adm profile throughput-performance 2>/dev/null || true

# ═══ WAYDROID PRE-CONFIGURATION (defaults for one-click init) ═══
mkdir -p /var/lib/waydroid /etc/waydroid
cat > /etc/waydroid/waydroid.cfg <<'EOWAYDROID'
[waydroid]
system_ota = https://ota.waydro.id/system
vendor_ota = https://ota.waydro.id/vendor
system_type = GAPPS
EOWAYDROID
mkdir -p /etc/libvirt/qemu.conf.d
echo -e "user = \"root\"\ngroup = \"root\"\ndynamic_ownership = 1\nremember_owner = 0" > /etc/libvirt/qemu.conf.d/10-cloudws.conf

# ═══ COCKPIT PLUGINS (git) ═══
git clone --depth=1 https://github.com/45Drives/cockpit-benchmark.git /tmp/bench && make -C /tmp/bench install && rm -rf /tmp/bench || true
git clone --depth=1 https://github.com/optimans/cockpit-zfs-manager.git /tmp/zfs && cp -r /tmp/zfs/zfs /usr/share/cockpit/ && rm -rf /tmp/zfs || true

# ═══ VIRTIO-WIN ISO ═══
mkdir -p /var/lib/libvirt/images
curl -Lo /var/lib/libvirt/images/virtio-win.iso \
    'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.271-1/virtio-win-0.1.271.iso' || true

# ═══ LOOKING GLASS B7 ═══
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
fi
rm -rf /tmp/LookingGlass

# Remove Looking Glass build deps
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
echo "[01-virt] Full KVM/Podman/Gaming/Cockpit/HA/CrowdSec + Looking Glass B7 installed."
'@|Out-File "$B\build_files\virtualization\01-virt.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  99-overrides.sh — User, hostname, self-embed, security, backup
# ════════════════════════════════════════════════════════════════════
$Ovr=@'
#!/bin/bash
set -euo pipefail

# ═══ USER SETUP (bootc: /home → /var/home symlink) ═══
# pam_mkhomedir ensures home dirs are created on login even if /var wasn't seeded
authselect select sssd with-mkhomedir --force 2>/dev/null || \
    echo "session optional pam_mkhomedir.so skel=/etc/skel umask=077" >> /etc/pam.d/system-auth
mkdir -p /var/home
useradd -m -d /var/home/INJ_U -s /bin/bash INJ_U 2>/dev/null || true
mkdir -p /var/home/INJ_U
chown INJ_U:INJ_U /var/home/INJ_U
chmod 700 /var/home/INJ_U
for d in Desktop Documents Downloads Music Pictures Public Templates Videos; do
    mkdir -p "/var/home/INJ_U/$d"
done
chown -R INJ_U:INJ_U /var/home/INJ_U

cat <<'EOF'|chpasswd
INJ_U:INJ_P
root:INJ_P
EOF
for g in wheel libvirt kvm video render input dialout; do
    groupadd -f "$g" 2>/dev/null || true
    usermod -aG "$g" INJ_U 2>/dev/null || true
done
sed -i 's/^# %wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel; chmod 440 /etc/sudoers.d/wheel
mkdir -p /etc/polkit-1/rules.d
echo 'polkit.addRule(function(a,s){if(s.isInGroup("wheel")){return polkit.Result.YES;}});' > /etc/polkit-1/rules.d/49-nopasswd-wheel.rules
echo 'polkit.addRule(function(a,s){if(a.id=="org.libvirt.unix.manage"&&s.local&&s.active&&s.isInGroup("libvirt")){return polkit.Result.YES;}});' > /etc/polkit-1/rules.d/49-nopasswd-libvirt.rules

echo 'alias scan-malware="podman run --rm -v ~/.clamav:/var/lib/clamav -v /var/home:/scandir:ro docker.io/clamav/clamav:latest clamscan -r /scandir"' >> /etc/skel/.bashrc

# cloudws-update — one-command system update
cat > /usr/local/bin/cloudws-update <<'EOUPDATE'
#!/bin/bash
set -euo pipefail
GHCR="ghcr.io/kabuki94/cloudws-bootc:latest"
echo ""
echo "  CloudWS Update — pulling from $GHCR"
echo "  ====================================="
echo ""
sudo bootc update
STATUS=$?
if [ $STATUS -eq 0 ]; then
    echo ""
    echo "  ✓ Update staged. Reboot to apply: sudo systemctl reboot"
else
    echo ""
    echo "  Trying bootc switch to GHCR..."
    sudo bootc switch "$GHCR" || echo "  ✗ Update failed. Check network connectivity."
fi
EOUPDATE
chmod +x /usr/local/bin/cloudws-update

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true

echo "CloudWS" > /etc/hostname
echo -e "127.0.0.1 localhost\n127.0.1.1 CloudWS CloudWS.local\n::1 localhost" > /etc/hosts
echo -e "PRETTY_HOSTNAME=\"CloudWS\"\nICON_NAME=\"computer\"\nCHASSIS=\"server\"" > /etc/machine-info
mkdir -p /etc/NetworkManager/conf.d; echo -e "[main]\nhostname-mode=none" > /etc/NetworkManager/conf.d/hostname.conf
cat > /usr/lib/systemd/system/cloudws-hostname.service <<'EOSVC'
[Unit]
Description=Enforce CloudWS Hostname
After=local-fs.target
Before=systemd-hostnamed.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo CloudWS > /etc/hostname;hostnamectl set-hostname CloudWS 2>/dev/null||true'
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOSVC
systemctl enable cloudws-hostname.service

# ═══ FIREWALL INIT (cloudws-firewall-init) ═══
cat > /usr/libexec/cloudws-firewall-init <<'EOFW'
#!/bin/bash
if command -v firewall-cmd &>/dev/null; then
    firewall-cmd --set-default-zone=drop
    firewall-cmd --permanent --zone=drop --add-service=cockpit
    firewall-cmd --permanent --zone=drop --add-service=ssh
    firewall-cmd --permanent --zone=drop --add-service=mdns
    firewall-cmd --permanent --zone=trusted --add-interface=podman0
    firewall-cmd --permanent --zone=trusted --add-interface=virbr0
    firewall-cmd --permanent --zone=trusted --add-interface=waydroid0
    # K3s pod/service subnets
    firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
    firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
    firewall-cmd --permanent --zone=drop --add-port=6443/tcp
    firewall-cmd --reload
fi
EOFW
chmod +x /usr/libexec/cloudws-firewall-init

# ═══ SELINUX FIXES (bootc image compatibility) ═══
# Fix file contexts at BUILD TIME — never use /.autorelabel on bootc/composefs
# because / is read-only and the file can never be removed, causing infinite reboot loops
if command -v restorecon &>/dev/null; then
    restorecon -R /boot 2>/dev/null || true
    restorecon -R /etc 2>/dev/null || true
    restorecon -R /usr 2>/dev/null || true
    restorecon -R /var 2>/dev/null || true
fi

# Fix specific SELinux denials reported on bootc deployments
if command -v semanage &>/dev/null; then
    # bootupd-state.json — needs boot_t label
    semanage fcontext -a -t boot_t '/boot/bootupd-state.json' 2>/dev/null || true
    restorecon -v /boot/bootupd-state.json 2>/dev/null || true

    # accountsservice interfaces — needs accountsd_var_lib_t
    semanage fcontext -a -t accountsd_var_lib_t '/usr/share/accountsservice/interfaces(/.*)?' 2>/dev/null || true
    restorecon -R /usr/share/accountsservice 2>/dev/null || true
fi

# Set booleans for cockpit, accounts-daemon, virt, NIS/rpcbind
if command -v setsebool &>/dev/null; then
    setsebool -P cockpit_manage_all_files 1 2>/dev/null || true
    setsebool -P domain_can_mmap_files 1 2>/dev/null || true
    setsebool -P daemons_dump_core 1 2>/dev/null || true
    setsebool -P virt_sandbox_use_all_caps 1 2>/dev/null || true
    setsebool -P virt_use_nfs 1 2>/dev/null || true
    setsebool -P nis_enabled 1 2>/dev/null || true
fi

# Build custom policy module for remaining bootc-specific denials
# (systemd-resolved socket, bootupctl, chcon mac_admin)
if command -v audit2allow &>/dev/null; then
    mkdir -p /tmp/selinux-fixes
    cat > /tmp/selinux-fixes/cloudws-bootc.te <<'EOTE'
module cloudws-bootc 1.0;

require {
    type bootupd_t;
    type boot_t;
    type init_t;
    type accountsd_t;
    type usr_t;
    type chcon_t;
    class file { read open getattr };
    class dir { watch };
    class capability { mac_admin };
}

# Allow bootupctl to read bootupd-state.json in /boot
allow bootupd_t boot_t:file { read open getattr };

# Allow accounts-daemon to watch its interfaces directory
allow accountsd_t usr_t:dir { watch };

# Allow chcon mac_admin capability (needed for SELinux relabeling)
allow chcon_t self:capability { mac_admin };
EOTE
    checkmodule -M -m -o /tmp/selinux-fixes/cloudws-bootc.mod /tmp/selinux-fixes/cloudws-bootc.te 2>/dev/null && \
    semodule_package -o /tmp/selinux-fixes/cloudws-bootc.pp -m /tmp/selinux-fixes/cloudws-bootc.mod 2>/dev/null && \
    semodule -X 300 -i /tmp/selinux-fixes/cloudws-bootc.pp 2>/dev/null || \
    echo "[WARN] Custom SELinux policy module failed — denials may persist on first boot."
    rm -rf /tmp/selinux-fixes
fi

# ═══ CLOUD-INIT ═══
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

# ═══ MULTIPATH / ZRAM / SYSCTL ═══
mkdir -p /etc/multipath
cat > /etc/multipath.conf <<'EOMP'
defaults {
    user_friendly_names yes
    find_multipaths yes
    polling_interval 10
}
EOMP

mkdir -p /usr/lib/systemd/zram-generator.conf.d
cat > /usr/lib/systemd/zram-generator.conf.d/cloudws.conf <<'EOZRAM'
[zram0]
zram-size = min(ram / 2, 32768)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOZRAM

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-cloudws-vmhost.conf <<'EOSYSCTL'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
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

# ═══ XRDP VSOCK + HYPER-V ═══
echo "hv_sock" > /etc/modules-load.d/hv_sock.conf
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

# ═══ CLOUDWS BACKUP HELPER (works on bare metal, WSL, containers) ═══
cat > /usr/local/bin/cloudws-backup <<'EOBAK'
#!/bin/bash
set -euo pipefail
echo "CloudWS Backup Utility"
echo "======================"
echo "1) Export WSL2 instance (from Windows host: wsl --export CloudWS backup.tar)"
echo "2) Backup Podman volumes"
echo "3) Backup K3s etcd snapshot"
echo "4) Backup libvirt VMs (XML + disks)"
echo "5) Full /var/home backup (tar.zst)"
echo ""
read -p "Choice [1-5]: " choice
STAMP=$(date +%Y%m%d-%H%M%S)
BDIR="/var/home/backups/cloudws-$STAMP"
mkdir -p "$BDIR"
case "$choice" in
  1) echo "Run from Windows PowerShell:"
     echo "  wsl --export CloudWS C:\\Backups\\cloudws-$STAMP.tar"
     echo "  # Or copy the VHDX directly from: %USERPROFILE%\\WSL\\CloudWS\\";;
  2) echo "Exporting Podman volumes..."
     for vol in $(podman volume ls -q 2>/dev/null); do
         podman volume export "$vol" > "$BDIR/podman-vol-$vol.tar"
         echo "  ✓ $vol"
     done;;
  3) echo "Snapshotting K3s etcd..."
     if [ -f /usr/local/bin/k3s ]; then
         k3s etcd-snapshot save --name "cloudws-$STAMP" 2>/dev/null || \
             cp -a /var/lib/rancher/k3s/server/db "$BDIR/k3s-db/" 2>/dev/null || true
         cp /var/lib/rancher/k3s/server/token "$BDIR/k3s-token" 2>/dev/null || true
         echo "  ✓ K3s state saved to $BDIR"
     else echo "  K3s not installed"; fi;;
  4) echo "Backing up libvirt VMs..."
     for vm in $(virsh list --all --name 2>/dev/null | grep -v "^$"); do
         virsh dumpxml "$vm" > "$BDIR/$vm.xml"
         echo "  ✓ $vm XML dumped"
     done
     echo "  Disk images at /var/lib/libvirt/images/ — copy separately for full backup.";;
  5) echo "Creating /var/home archive..."
     tar -cf - -C /var home | zstd -T0 -3 > "$BDIR/var-home.tar.zst"
     echo "  ✓ $BDIR/var-home.tar.zst";;
  *) echo "Invalid choice.";;
esac
echo ""
echo "Backups stored in: $BDIR"
EOBAK
chmod +x /usr/local/bin/cloudws-backup

# ═══ FIRST-BOOT SYSTEM INIT (SECURITY + USER SETUP) ═══
cat > /usr/lib/systemd/system/cloudws-init.service <<'EOSVC'
[Unit]
Description=CloudWS System Init
After=network.target
Before=gdm.service display-manager.service
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

# Flatpak remotes — re-ensure they're present (bootc /var seeding may miss metadata)
flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
flatpak remote-add --if-not-exists --system flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo 2>/dev/null || true
flatpak remote-add --if-not-exists --system gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo 2>/dev/null || true
echo "[cloudws-init] Flatpak remotes: $(flatpak remotes --system --columns=name | tr '\n' ' ')"
echo "[cloudws-init] Flatpak apps: $(flatpak list --system --app --columns=application 2>/dev/null | wc -l)"

/usr/libexec/cloudws-firewall-init || true

for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
    home=$(getent passwd "$u" | cut -d: -f6)
    if [ ! -d "$home" ]; then
        mkdir -p "$home"
        cp -a /etc/skel/. "$home/" 2>/dev/null || true
        for d in Desktop Documents Downloads Music Pictures Public Templates Videos; do
            mkdir -p "$home/$d"
        done
        chown -R "$u:$u" "$home"
        chmod 700 "$home"
    fi
    su - "$u" -c "xdg-user-dirs-update" 2>/dev/null || true
done

for g in wheel libvirt kvm video render input dialout; do
    groupadd -f "$g" 2>/dev/null || true
    for u in $(awk -F: '$3 >= 1000 && $3 < 65000 {print $1}' /etc/passwd); do
        usermod -aG "$g" "$u" 2>/dev/null || true
    done
done

if command -v pmlogger_check &>/dev/null; then
    mkdir -p /var/log/pcp/pmlogger
    systemctl restart pmcd pmlogger pmproxy 2>/dev/null || true
fi
bootc status 2>/dev/null || true
echo "[cloudws-init] System initialization complete."
EOINIT
chmod +x /usr/libexec/cloudws-init; systemctl enable cloudws-init.service

# ═══ GPU AUTO-DETECT (blocks NVIDIA in VMs, runs BEFORE GDM) ═══
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

    # Block all NVIDIA kernel modules (no physical GPU in VM)
    cat > "$NVIDIA_CONF" <<'EOMOD'
# CloudWS auto-generated: VM detected, no physical NVIDIA GPU
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nvidia_uvm /bin/false
EOMOD

    # Unload NVIDIA modules if somehow already loaded
    for mod in nvidia_uvm nvidia_drm nvidia_modeset nvidia; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    # Ensure virtual GPU driver is available
    case "$VIRT" in
        microsoft)
            modprobe hyperv_drm 2>/dev/null || true
            echo "[cloudws-gpu-detect] Hyper-V: hyperv_drm active"
            ;;
        kvm|qemu)
            modprobe virtio-gpu 2>/dev/null || true
            echo "[cloudws-gpu-detect] KVM/QEMU: virtio-gpu active"
            ;;
        vmware)
            modprobe vmwgfx 2>/dev/null || true
            echo "[cloudws-gpu-detect] VMware: vmwgfx active"
            ;;
    esac
else
    echo "[cloudws-gpu-detect] Bare metal — NVIDIA modules enabled"
    # Remove any VM override from a previous boot (e.g. migrated disk)
    rm -f "$NVIDIA_CONF" 2>/dev/null || true
fi

touch /run/cloudws-gpu-detected
echo "[cloudws-gpu-detect] GPU environment configured."
EOGPU
chmod +x /usr/libexec/cloudws-gpu-detect
systemctl enable cloudws-gpu-detect.service

echo "[99-overrides] User + hostname + security + GPU-detect + backup configured."
'@
$Ovr.Replace('INJ_U',$U).Replace('INJ_P',$P)|Out-File "$B\build_files\system\99-overrides.sh" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  Containerfile — OCI labels + GitHub-based cloudws-rebuild + lint
# ════════════════════════════════════════════════════════════════════
$BuildDate = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
@"
FROM scratch AS ctx
COPY build_files /build_files
FROM quay.io/fedora/fedora-bootc:rawhide
LABEL org.opencontainers.image.title="CloudWS — Cloud Workstation OS" \
      org.opencontainers.image.description="Fedora Rawhide bootc immutable workstation: GNOME 50, Flatpak-first, KVM/QEMU GPU passthrough, Podman, K3s HA, NVIDIA RTX 4090, Gamescope Steam Session" \
      org.opencontainers.image.version="3.13.0" \
      org.opencontainers.image.created="$BuildDate" \
      org.opencontainers.image.authors="Kabuki94" \
      org.opencontainers.image.source="https://github.com/Kabuki94/CloudWS-bootc" \
      org.opencontainers.image.vendor="CloudWS" \
      org.opencontainers.image.licenses="MIT" \
      containers.bootc=1
RUN dnf upgrade -y --refresh --allowerasing --nobest && dnf clean all
RUN --mount=type=bind,from=ctx,source=/build_files,target=/tmp/staging \
    mkdir -p /tmp/scripts && cp -r /tmp/staging/* /tmp/scripts/ && \
    find /tmp/scripts -name "*.sh" -exec sed -i 's/\r//g' {} + && chmod +x /tmp/scripts/*/*.sh && \
    bash /tmp/scripts/base/01-repos.sh && \
    bash /tmp/scripts/base/02-kernel.sh && \
    bash /tmp/scripts/desktop/01-gnome.sh && \
    bash /tmp/scripts/hardware/01-hardware.sh && \
    bash /tmp/scripts/virtualization/01-virt.sh && \
    bash /tmp/scripts/system/99-overrides.sh && \
    mkdir -p /usr/share/cloudws/build_files && cp -r /tmp/staging/* /usr/share/cloudws/build_files/ && \
    dnf clean all && \
    rm -rf /var/cache/dnf /var/cache/libdnf5 /var/cache/pip /var/lib/dnf/repos /tmp/scripts /tmp/*.log /var/tmp/* /root/.cache && \
    rm -rf /var/log/dnf* /var/log/hawkey* /var/log/anaconda 2>/dev/null && \
    rm -rf /usr/share/doc /usr/share/man /usr/share/info /usr/share/gtk-doc 2>/dev/null && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name 'en' ! -name 'en_US' -exec rm -rf {} + 2>/dev/null && \
    rm -rf /tmp/* /var/tmp/* 2>/dev/null && \
    find /var/log -type f -name "*.log" -delete 2>/dev/null; true
COPY Containerfile /usr/share/cloudws/Containerfile
COPY <<'EOREBUILD' /usr/local/bin/cloudws-rebuild
#!/bin/bash
set -euo pipefail
REPO="https://github.com/Kabuki94/CloudWS-bootc.git"
GHCR="ghcr.io/kabuki94/cloudws-bootc"
WORKDIR="/tmp/cloudws-rebuild-`$(date +%s)"
echo ""
echo "  CloudWS Self-Replication Engine v3.13"
echo "  ======================================"
echo "  1) Clone from GitHub → Build → local image"
echo "  2) Clone from GitHub → Build → Push to GHCR"
echo "  3) Push existing local image to GHCR"
echo "  4) Pull latest from GHCR (bootc switch)"
echo "  5) Update in-place from GHCR (bootc update)"
echo "  6) Rollback to previous deployment"
echo "  7) Show bootc status"
echo "  8) Rebuild from embedded sources (offline)"
echo ""
read -p "  Choice [1-8]: " choice
case "`$choice" in
  1) echo ""; echo "Cloning `$REPO..."
     rm -rf "`$WORKDIR"; git clone --depth=1 "`$REPO" "`$WORKDIR"
     cd "`$WORKDIR"
     podman build --no-cache -t localhost/cloudws:latest .
     rm -rf "`$WORKDIR"
     echo ""; echo "Done. Deploy with:"
     echo "  sudo bootc switch --transport containers-storage localhost/cloudws:latest";;
  2) echo ""; echo "Cloning `$REPO..."
     rm -rf "`$WORKDIR"; git clone --depth=1 "`$REPO" "`$WORKDIR"
     cd "`$WORKDIR"
     podman build --no-cache -t localhost/cloudws:latest .
     rm -rf "`$WORKDIR"
     read -p "  GitHub username: " ghu
     read -sp "  GitHub PAT (write:packages): " ghp; echo
     echo "`$ghp" | podman login ghcr.io -u "`$ghu" --password-stdin
     podman tag localhost/cloudws:latest "`$GHCR:latest"
     podman tag localhost/cloudws:latest "`$GHCR:`$(date +%Y%m%d)"
     podman push "`$GHCR:latest"
     podman push "`$GHCR:`$(date +%Y%m%d)"
     echo ""; echo "Pushed to `$GHCR:latest and `$GHCR:`$(date +%Y%m%d)";;
  3) read -p "  GitHub username: " ghu
     read -sp "  GitHub PAT (write:packages): " ghp; echo
     echo "`$ghp" | podman login ghcr.io -u "`$ghu" --password-stdin
     podman tag localhost/cloudws:latest "`$GHCR:latest"
     podman push "`$GHCR:latest"
     echo "Pushed to `$GHCR:latest";;
  4) echo "Switching to `$GHCR:latest..."
     sudo bootc switch "`$GHCR:latest"
     echo "Staged. Reboot to apply.";;
  5) echo "Checking for updates..."
     sudo bootc update
     echo "Done. Reboot if updates were staged.";;
  6) echo "Rolling back..."
     sudo bootc rollback
     echo "Rolled back. Reboot to apply.";;
  7) bootc status;;
  8) echo "Rebuilding from embedded sources..."
     cd /usr/share/cloudws
     podman build --no-cache -t localhost/cloudws:latest -f Containerfile .
     echo "Done. Deploy with:"
     echo "  sudo bootc switch --transport containers-storage localhost/cloudws:latest";;
  *) echo "Invalid choice.";;
esac
EOREBUILD
RUN chmod +x /usr/local/bin/cloudws-rebuild
RUN mkdir -p /usr/lib/bootc/install && printf '[install.filesystem.root]\ntype = "xfs"\n' > /usr/lib/bootc/install/00-cloudws.toml
RUN bootc container lint
"@|Out-File "$B\Containerfile" -Encoding ascii

# ════════════════════════════════════════════════════════════════════
#  PHASE 3: BUILD OCI IMAGE
# ════════════════════════════════════════════════════════════════════
Write-Host "`n═══ Phase 3: Building OCI Image ═══" -ForegroundColor Cyan
podman build --no-cache -t $I $B
if($LASTEXITCODE -ne 0){throw "Build failed"}
Write-Host "  ✓ OCI image built: localhost/$I" -ForegroundColor Green

# Tag as GHCR so bootc update knows where to pull from (even if not pushing yet)
$GhcrRef = "${GhcrImage}:latest"
podman tag "localhost/$I" $GhcrRef
Write-Host "  ✓ Tagged as $GhcrRef (bootc update target)" -ForegroundColor Green

# ════════════════════════════════════════════════════════════════════
#  PHASE 4: EXPORT TARGETS (conditional)
# ════════════════════════════════════════════════════════════════════
# config.toml — minimum root partition (VHDX dynamic format only uses actual space)
@"
[[customizations.filesystem]]
mountpoint = "/"
minsize = "60 GiB"
"@ | Out-File "$O\config.toml" -Encoding ascii

$bib="quay.io/centos-bootc/bootc-image-builder:latest"
$bibV=@("--rm","-it","--privileged","--security-opt","label=type:unconfined_t","-v","/var/lib/containers/storage:/var/lib/containers/storage","-v","${O}:/output:z","-v","${O}/config.toml:/config.toml:z")

if ($buildRaw -eq 'y') {
    Write-Host "Building RAW disk image..." -ForegroundColor Cyan
    $bibArgs = @("build","--type","raw","--rootfs","ext4","--config","/config.toml")
    if ($enableLuks -eq 'y' -and $luksPass) { $bibArgs += @("--luks-passphrase",$luksPass) }
    $bibArgs += $GhcrRef
    podman run @bibV $bib @bibArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ RAW disk build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        $buildVhdx = 'n'
    } else {
        $Raw=(Get-ChildItem $O -Filter "disk.raw" -Recurse|Sort LastWriteTime -Desc|Select -First 1)
        if($Raw){if(Test-Path $R_Img){rm $R_Img -Force};$z=0;while($z -lt 12){try{Move-Item $Raw.FullName $R_Img -Force;break}catch{Start-Sleep 5;$z++}}}
    }
}

if ($buildVhdx -eq 'y' -and (Test-Path $R_Img)) {
    Write-Host "Converting RAW → VHDX..." -ForegroundColor Cyan
    if(Test-Path $T_V){rm $T_V -Force}
    podman run --rm -v "${O}:/data:z" docker.io/alpine:latest sh -c "apk add --no-cache qemu-img && qemu-img convert -p -f raw -O vhdx -o subformat=dynamic /data/$(Split-Path $R_Img -Leaf) /data/cloudws-hyperv.vhdx"
    if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ VHDX conversion failed (exit $LASTEXITCODE)" -ForegroundColor Red }
}

if ($buildWsl -eq 'y') {
    Write-Host "Exporting WSL tarball..." -ForegroundColor Cyan
    podman rm wsl-tmp 2>$null;podman create --name wsl-tmp $I|Out-Null;if(Test-Path $T_W){rm $T_W -Force};podman export -o $T_W wsl-tmp;podman rm wsl-tmp|Out-Null
}

if ($buildIso -eq 'y') {
    Write-Host "Building Anaconda installer ISO..." -ForegroundColor Cyan
    $bibIsoArgs = @("build","--type","anaconda-iso","--rootfs","ext4","--config","/config.toml")
    if ($enableLuks -eq 'y' -and $luksPass) { $bibIsoArgs += @("--luks-passphrase",$luksPass) }
    $bibIsoArgs += $GhcrRef
    podman run @bibV $bib @bibIsoArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Anaconda ISO build failed (exit $LASTEXITCODE)" -ForegroundColor Red
    } else {
        $Iso=(Get-ChildItem $O -Filter "*.iso" -Recurse|?{$_.Name -ne "cloudws-installer.iso" -and $_.Name -ne "cloudws-live.iso"}|Sort LastWriteTime -Desc|Select -First 1)
        if($Iso){if(Test-Path $T_I){rm $T_I -Force};$z=0;while($z -lt 12){try{Move-Item $Iso.FullName $T_I -Force;break}catch{Start-Sleep 5;$z++}}}
    }
}

if ($buildLive -eq 'y') {
    Write-Host "Building Live USB ISO..." -ForegroundColor Cyan
    podman run @bibV $bib build --type iso --rootfs ext4 --config /config.toml $GhcrRef
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Live ISO build failed (exit $LASTEXITCODE)" -ForegroundColor Red
    } else {
        $Live=(Get-ChildItem $O -Filter "*.iso" -Recurse|?{$_.Name -ne "cloudws-installer.iso" -and $_.Name -ne "cloudws-live.iso"}|Sort LastWriteTime -Desc|Select -First 1)
        if($Live){if(Test-Path $T_L){rm $T_L -Force};$z=0;while($z -lt 12){try{Move-Item $Live.FullName $T_L -Force;break}catch{Start-Sleep 5;$z++}}}
    }
}

Write-Host "`n═══ Export Summary ═══" -ForegroundColor Green
Write-Host "  OCI:  localhost/$I" -ForegroundColor White
if ($buildRaw  -eq 'y') { Write-Host "  RAW:  $R_Img$(if(Test-Path $R_Img){' ✓'}else{' ✗'})" -ForegroundColor White }
if ($buildVhdx -eq 'y') { Write-Host "  VHDX: $T_V$(if(Test-Path $T_V){' ✓'}else{' ✗'})" -ForegroundColor White }
if ($buildWsl  -eq 'y') { Write-Host "  WSL:  $T_W$(if(Test-Path $T_W){' ✓'}else{' ✗'})" -ForegroundColor White }
if ($buildIso  -eq 'y') { Write-Host "  ISO:  $T_I$(if(Test-Path $T_I){' ✓'}else{' ✗'})" -ForegroundColor White }
if ($buildLive -eq 'y') { Write-Host "  LIVE: $T_L$(if(Test-Path $T_L){' ✓'}else{' ✗'})" -ForegroundColor White }

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: LOCAL DEPLOYMENT (uses upfront answers — no prompts)
# ══════════════════════════════════════════════════════════════════════════════

# ── WSL2 / WSLg ──
if ($deployWsl -eq 'y' -and (Test-Path $T_W)) {
    Write-Host "`n═══ Deploying to WSL2 ═══" -ForegroundColor Cyan
    $wslName = "CloudWS"
    $wslPath = Join-Path $env:USERPROFILE "WSL\$wslName"

    $existing = wsl --list --quiet 2>$null | Where-Object { $_ -match "^$wslName$" }
    if ($existing) {
        Write-Host "  Removing existing '$wslName' WSL instance..." -ForegroundColor DarkGray
        wsl --unregister $wslName 2>$null
    }
    if (!(Test-Path $wslPath)) { New-Item -ItemType Directory -Path $wslPath -Force | Out-Null }

    wsl --import $wslName $wslPath $T_W --version 2
    if ($LASTEXITCODE -eq 0) {
        $wslConf = "[user]`ndefault=$U`n`n[boot]`nsystemd=true`n`n[interop]`nappendWindowsPath=false`n`n[automount]`nenabled=true`nmountFsTab=true"
        wsl -d $wslName -- bash -c "echo '$wslConf' > /etc/wsl.conf"
        wsl -d $wslName -- bash -c "systemctl mask auditd.service audit-rules.service bootloader-update.service 2>/dev/null; true"
        wsl -d $wslName -- bash -c "localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null; true"
        wsl --terminate $wslName 2>$null
        Write-Host "  ✓ CloudWS deployed to WSL2 as '$wslName'" -ForegroundColor Green
        Write-Host "    wsl.conf: systemd=true, appendWindowsPath=false" -ForegroundColor Gray
        if ($deployWslDefault -eq 'y') {
            wsl --set-default $wslName
            Write-Host "  ✓ Set as default WSL distro" -ForegroundColor Green
        }
    } else { Write-Host "  ✗ WSL import failed" -ForegroundColor Red }
}

# ── Hyper-V VM ──
if ($deployHyperV -eq 'y' -and (Test-Path $T_V)) {
    Write-Host "`n═══ Creating Hyper-V VM ═══" -ForegroundColor Cyan
    $vmName = "CloudWS"
    $vmPath = Join-Path $env:USERPROFILE "Hyper-V\$vmName"
    if (!(Test-Path $vmPath)) { New-Item -ItemType Directory -Path $vmPath -Force | Out-Null }

    $vmDisk = Join-Path $vmPath "cloudws.vhdx"
    Copy-Item $T_V $vmDisk -Force

    $existingVM = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Host "  Removing existing '$vmName' VM..." -ForegroundColor DarkGray
        Stop-VM -Name $vmName -Force -ErrorAction SilentlyContinue
        Remove-VM -Name $vmName -Force
    }

    $vmRam = [math]::Min($r, 16384) * 1MB
    $vmCpu = [math]::Min($c, 16)
    New-VM -Name $vmName -MemoryStartupBytes $vmRam -Generation 2 -VHDPath $vmDisk -SwitchName (Get-VMSwitch | Select-Object -First 1).Name
    Set-VM -Name $vmName -ProcessorCount $vmCpu -DynamicMemory -MemoryMinimumBytes 2048MB -MemoryMaximumBytes $vmRam
    Set-VMFirmware -VMName $vmName -EnableSecureBoot Off
    Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true
    Write-Host "  ✓ Hyper-V VM '$vmName' created (Gen2, ${vmCpu}CPU, $([math]::Round($vmRam/1GB))GB RAM)" -ForegroundColor Green

    if ($startVm -eq 'y') {
        Start-VM -Name $vmName
        Write-Host "  ✓ VM starting..." -ForegroundColor Green
        vmconnect localhost $vmName 2>$null
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 6: GHCR PUSH (absolute last step)
# ══════════════════════════════════════════════════════════════════════════════
if ($ghcrReady) {
    Write-Host "`n═══ Phase 6: Pushing to GHCR ═══" -ForegroundColor Cyan
    $dateTag = Get-Date -Format 'yyyyMMdd'
    podman tag "localhost/$I" "${GhcrImage}:latest"
    podman tag "localhost/$I" "${GhcrImage}:${dateTag}"
    podman push "${GhcrImage}:latest"
    if ($LASTEXITCODE -eq 0) {
        podman push "${GhcrImage}:${dateTag}"
        Write-Host "  ✓ Pushed ${GhcrImage}:latest" -ForegroundColor Green
        Write-Host "  ✓ Pushed ${GhcrImage}:${dateTag}" -ForegroundColor Green
    } else {
        Write-Host "  ✗ GHCR push failed" -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n═══ All Done ═══" -ForegroundColor Green
Write-Host ""
Write-Host "  CloudWS Self-Management (from a running CloudWS system):" -ForegroundColor Cyan
Write-Host "    cloudws-rebuild          — Clone from GitHub, build, push, pull, update, rollback" -ForegroundColor White
Write-Host "    cloudws-backup           — Backup Podman volumes, K3s state, VMs, home dirs" -ForegroundColor White
Write-Host "    cloudws-vfio-toggle list — Show GPUs + IOMMU groups for passthrough" -ForegroundColor White
Write-Host "    sudo bootc update        — Pull latest image from GHCR" -ForegroundColor White
Write-Host "    sudo bootc switch $GhcrImage`:latest — Switch to GHCR image" -ForegroundColor White
Write-Host "    sudo bootc rollback      — Roll back to previous deployment" -ForegroundColor White
Write-Host ""
Write-Host "  GDM Session Selection:" -ForegroundColor Cyan
Write-Host "    GNOME (Wayland)          — Full desktop environment" -ForegroundColor White
Write-Host "    Steam (Gamescope)        — Fullscreen SteamOS-mode gaming session" -ForegroundColor White
Write-Host ""
Write-Host "  WSL2 Backup (from Windows):" -ForegroundColor Cyan
Write-Host "    wsl --export CloudWS backup.tar" -ForegroundColor White
Write-Host ""
Write-Host "  GitHub Setup (one-time):" -ForegroundColor Yellow
Write-Host "    1. https://github.com/settings/tokens/new (write:packages, read:packages)" -ForegroundColor Gray
Write-Host "    2. https://github.com/new → 'CloudWS-bootc'" -ForegroundColor Gray
Write-Host "    3. Make package public: https://github.com/Kabuki94?tab=packages" -ForegroundColor Gray
Write-Host ""
