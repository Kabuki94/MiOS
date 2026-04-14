<#
.SYNOPSIS  CloudWS v2.1.2 — 7 runtime fixes + Ceph single-node bootstrap
.DESCRIPTION
    1. SELinux MODNAME: remove broken appended blocks, add to CLOUDWS_POLICIES array
    2. Cockpit: external access on ALL interfaces
    3. GTK theming: GSchema override (Bazzite pattern)
    4. WSL2: dbus-broker + systemd-machined drop-ins
    5. Phosh: mobile session + portrait VM
    6. Window controls: survive Phosh/GNOME switches
    7. Ceph: single-node pre-configured bootstrap + cloudws-ceph tool
#>
$ErrorActionPreference = "Stop"

function Write-UnixFile {
    param([string]$Path, [string]$Content)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location) $Path),
        $Content.Replace("`r`n", "`n"),
        [System.Text.UTF8Encoding]::new($false))
}

if (-not (Test-Path "Containerfile") -or -not (Test-Path "scripts/build.sh")) {
    Write-Host "  ERROR: Run from CloudWS-bootc repo root" -ForegroundColor Red; exit 1
}

Write-Host "`n  CloudWS v2.1.2 — 7 Fixes + Ceph Bootstrap`n" -ForegroundColor Cyan
$changes = 0

# ═══════════════════════════════════════════════════════════════════════
# FIX 1: SELINUX — Remove broken MODNAME blocks, add to CLOUDWS_POLICIES
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [1/7] SELinux — CLOUDWS_POLICIES array fix..." -ForegroundColor Yellow
$seScript = "scripts/37-selinux.sh"
if (Test-Path $seScript) {
    $se = [System.IO.File]::ReadAllText((Resolve-Path $seScript).Path)

    # Remove broken content after "SELinux configuration complete"
    if ($se -match '(?s)(.*echo "\[37-selinux\] SELinux configuration complete\.").*$') {
        $se = $Matches[1]
        Write-Host "    ~ Removed broken appended MODNAME blocks" -ForegroundColor Green
        $changes++
    }

    # Add new policies to CLOUDWS_POLICIES array (same safe pattern as existing)
    $newPolicies = @'

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
'@

    if ($se -match '(\s+for name in "\$\{!CLOUDWS_POLICIES\[@\]\}")') {
        $se = $se -replace '(\s+for name in "\$\{!CLOUDWS_POLICIES\[@\]\}")', "$newPolicies`n`$1"
        Write-Host "    + 5 policies added to array" -ForegroundColor Green
        $changes++
    }
    Write-UnixFile $seScript $se
}

# ═══════════════════════════════════════════════════════════════════════
# FIX 2: COCKPIT
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [2/7] Cockpit — external access..." -ForegroundColor Yellow
Write-UnixFile "system_files/etc/cockpit/cockpit.conf" @"
[WebService]
AllowUnencrypted = true
LoginTitle = CloudWS Management Console
MaxStartups = 10
IdleTimeout = 15

[Log]
Fatal = criticals warnings
"@
Write-UnixFile "system_files/etc/systemd/system/cockpit.socket.d/listen-all.conf" @"
[Socket]
ListenStream=
ListenStream=0.0.0.0:9090
ListenStream=[::]:9090
FreeBind=yes
"@
Write-Host "    + cockpit.conf + socket override" -ForegroundColor Green
$changes++

$fwScript = "scripts/33-firewall.sh"
if (Test-Path $fwScript) {
    $fw = [System.IO.File]::ReadAllText((Resolve-Path $fwScript).Path)
    if ($fw -notmatch 'add-service.*cockpit') {
        $cb = "`n# Cockpit all zones`nfor zone in public libvirt trusted; do`n    firewall-cmd --permanent --zone=`"`$zone`" --add-service=cockpit 2>/dev/null || true`n    firewall-cmd --permanent --zone=`"`$zone`" --add-port=9090/tcp 2>/dev/null || true`ndone`n"
        if ($fw -match 'firewall-cmd\s+--reload') { $fw = $fw -replace '(firewall-cmd\s+--reload)', "$cb`$1" }
        else { $fw += $cb }
        Write-UnixFile $fwScript $fw
        Write-Host "    ~ 33-firewall.sh patched" -ForegroundColor Green
        $changes++
    }
}

# ═══════════════════════════════════════════════════════════════════════
# FIX 3: GTK THEMING
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [3/7] GTK theming — GSchema override..." -ForegroundColor Yellow
Write-UnixFile "system_files/usr/share/glib-2.0/schemas/90-cloudws.gschema.override" @"
[org.gnome.desktop.interface]
gtk-theme='adw-gtk3-dark'
icon-theme='Adwaita'
cursor-theme='Bibata-Modern-Classic'
cursor-size=24
color-scheme='prefer-dark'
font-name='Cantarell 11'
monospace-font-name='Geist Mono 10'

[org.gnome.desktop.wm.preferences]
button-layout='close,minimize,maximize:'

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/gnome/amber-l.jxl'
picture-uri-dark='file:///usr/share/backgrounds/gnome/amber-d.jxl'
picture-options='zoom'
primary-color='#241f31'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/amber-d.jxl'

[org.gnome.software]
allow-updates=false
download-updates=false
"@
Write-UnixFile "system_files/etc/skel/.config/gtk-3.0/settings.ini" "[Settings]`ngtk-theme-name=adw-gtk3-dark`ngtk-icon-theme-name=Adwaita`ngtk-cursor-theme-name=Bibata-Modern-Classic`ngtk-cursor-theme-size=24`ngtk-application-prefer-dark-theme=1`n"
Write-UnixFile "system_files/etc/skel/.config/gtk-4.0/settings.ini" "[Settings]`ngtk-cursor-theme-name=Bibata-Modern-Classic`ngtk-cursor-theme-size=24`n"
Write-Host "    + GSchema + GTK3/4 skel" -ForegroundColor Green
$changes++

$themeScript = "scripts/30-locale-theme.sh"
if (Test-Path $themeScript) {
    $ts = [System.IO.File]::ReadAllText((Resolve-Path $themeScript).Path)
    if ($ts -notmatch 'glib-compile-schemas') {
        $ts += "`n`necho `"[30-locale-theme] Compiling GSchema overrides...`"`nglib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true`ndconf update 2>/dev/null || true`n"
        Write-UnixFile $themeScript $ts
        Write-Host "    ~ 30-locale-theme.sh — glib-compile-schemas" -ForegroundColor Green
        $changes++
    }
}

# ═══════════════════════════════════════════════════════════════════════
# FIX 4: WSL2
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [4/7] WSL2 — dbus-broker + machined..." -ForegroundColor Yellow
Write-UnixFile "system_files/etc/systemd/system/dbus-broker.service.d/wsl2-fix.conf" "[Unit]`nConditionPathExists=|/proc/sys/fs/binfmt_misc/WSLInterop`n`n[Service]`nExecStart=`nExecStart=/usr/bin/dbus-broker-launch --scope system`nOOMScoreAdjust=-500`n"
Write-UnixFile "system_files/etc/systemd/system/systemd-machined.service.d/wsl2-optional.conf" "[Unit]`nConditionVirtualization=!wsl`n"
Write-Host "    + WSL2 drop-ins" -ForegroundColor Green
$changes++

# ═══════════════════════════════════════════════════════════════════════
# FIX 5: PHOSH
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [5/7] Phosh — mobile session..." -ForegroundColor Yellow
Write-UnixFile "system_files/usr/share/wayland-sessions/phosh.desktop" "[Desktop Entry]`nName=Phosh (Mobile)`nComment=CloudWS mobile session`nExec=/usr/bin/phosh-session`nType=Application`nDesktopNames=Phosh;GNOME;`n"
Write-Host "    + phosh.desktop" -ForegroundColor Green
$changes++

$pkgMd = "PACKAGES.md"
if ((Test-Path $pkgMd) -and ((Get-Content $pkgMd -Raw) -notmatch 'packages-phosh')) {
    Add-Content -Path $pkgMd -Value "`n### Phosh (Mobile Session)`n``````packages-phosh`nphosh`nphoc`nsqueekboard`nfeedbackd`n```````n" -NoNewline
    Write-Host "    ~ PACKAGES.md — phosh section" -ForegroundColor Green
    $changes++
}

$gnomeScript = "scripts/10-gnome.sh"
if ((Test-Path $gnomeScript) -and ((Get-Content $gnomeScript -Raw) -notmatch 'install_packages.*phosh')) {
    $gs = [System.IO.File]::ReadAllText((Resolve-Path $gnomeScript).Path)
    $gs += "`n`necho `"[10-gnome] Installing Phosh mobile session...`"`ninstall_packages_optional `"phosh`"`n"
    Write-UnixFile $gnomeScript $gs
    Write-Host "    ~ 10-gnome.sh — phosh install" -ForegroundColor Green
    $changes++
}

# ═══════════════════════════════════════════════════════════════════════
# FIX 6: WINDOW CONTROLS
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [6/7] Window controls — autostart restore..." -ForegroundColor Yellow
Write-UnixFile "system_files/etc/xdg/autostart/cloudws-restore-buttons.desktop" "[Desktop Entry]`nType=Application`nName=CloudWS Window Controls`nExec=gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'`nNoDisplay=true`nX-GNOME-Autostart-Phase=Applications`nOnlyShowIn=GNOME;`n"
Write-Host "    + autostart restore" -ForegroundColor Green
$changes++

# ═══════════════════════════════════════════════════════════════════════
# FIX 7: CEPH SINGLE-NODE BOOTSTRAP
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [7/7] Ceph — single-node bootstrap..." -ForegroundColor Yellow

# systemd service
Write-UnixFile "system_files/usr/lib/systemd/system/cloudws-ceph-bootstrap.service" @"
[Unit]
Description=CloudWS Ceph Single-Node Bootstrap
After=network-online.target podman.service
Wants=network-online.target
ConditionPathExists=!/var/lib/ceph/.cloudws-bootstrapped
ConditionVirtualization=!container

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/cloudws-ceph-bootstrap
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
"@
Write-Host "    + cloudws-ceph-bootstrap.service" -ForegroundColor Green

# Bootstrap script — runs on first boot, creates entire Ceph cluster
$bootstrapScript = @'
#!/bin/bash
set -euo pipefail
SENTINEL="/var/lib/ceph/.cloudws-bootstrapped"
LOG="/var/log/cloudws-ceph-bootstrap.log"
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
[ -f "$SENTINEL" ] && { log "Already bootstrapped"; exit 0; }

log "=== CloudWS Ceph Single-Node Bootstrap ==="
command -v cephadm &>/dev/null || { log "ERROR: cephadm not found"; exit 1; }

PRIMARY_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
[ -z "$PRIMARY_IP" ] && PRIMARY_IP=$(hostname -I | awk '{print $1}')
log "IP: ${PRIMARY_IP}, Host: $(hostname -s)"

mkdir -p /var/lib/ceph /var/log/ceph /etc/ceph

log "Running cephadm bootstrap..."
cephadm bootstrap \
    --mon-ip "${PRIMARY_IP}" \
    --initial-dashboard-user cloudws \
    --initial-dashboard-password cloudws \
    --dashboard-password-noupdate \
    --allow-fqdn-hostname \
    --single-host-defaults \
    --skip-firewalld \
    --skip-monitoring-stack \
    --cleanup-on-failure 2>&1 | tee -a "$LOG"

sleep 5
cephadm shell -- ceph config set global osd_pool_default_size 1 2>/dev/null || true
cephadm shell -- ceph config set global osd_pool_default_min_size 1 2>/dev/null || true
cephadm shell -- ceph config set global mon_allow_pool_size_one true 2>/dev/null || true

log "Creating CephFS + RBD pools..."
cephadm shell -- ceph fs volume create cloudws-fs 2>/dev/null || true
cephadm shell -- ceph osd pool create cloudws-rbd 32 2>/dev/null || true
cephadm shell -- ceph osd pool application enable cloudws-rbd rbd 2>/dev/null || true
cephadm shell -- rbd pool init cloudws-rbd 2>/dev/null || true
cephadm shell -- ceph osd pool create cloudws-backup 16 2>/dev/null || true
cephadm shell -- ceph osd pool application enable cloudws-backup rbd 2>/dev/null || true

for port in 6789/tcp 6800-7300/tcp 8443/tcp 3300/tcp 8080/tcp; do
    firewall-cmd --permanent --add-port=$port 2>/dev/null || true
done
firewall-cmd --reload 2>/dev/null || true

FSID=$(cephadm shell -- ceph fsid 2>/dev/null || echo "unknown")
cat > /etc/ceph/cloudws-join-info.json <<EOF
{"master_ip":"${PRIMARY_IP}","fsid":"${FSID}","dashboard":"https://${PRIMARY_IP}:8443","cephfs":"cloudws-fs","rbd":"cloudws-rbd","backup":"cloudws-backup"}
EOF

touch "$SENTINEL"
log "=== Complete. Dashboard: https://${PRIMARY_IP}:8443 ==="
'@
Write-UnixFile "system_files/usr/local/bin/cloudws-ceph-bootstrap" $bootstrapScript
Write-Host "    + cloudws-ceph-bootstrap" -ForegroundColor Green

# cloudws-ceph management CLI
$cephCli = @'
#!/bin/bash
set -euo pipefail
case "${1:-help}" in
    status)    cephadm shell -- ceph status 2>/dev/null; cephadm shell -- ceph df 2>/dev/null ;;
    bootstrap) /usr/local/bin/cloudws-ceph-bootstrap ;;
    join)      MASTER="${2:?Usage: cloudws-ceph join <ip>}"
               scp "cloudws@${MASTER}:/etc/ceph/ceph.conf" /etc/ceph/ && \
               scp "cloudws@${MASTER}:/etc/ceph/ceph.client.admin.keyring" /etc/ceph/ && \
               ssh "cloudws@${MASTER}" "cephadm shell -- ceph orch host add $(hostname -s) $(hostname -I|awk '{print $1}')" && \
               echo "Joined. OSDs auto-provision on available disks." ;;
    reset)     read -p "Type DESTROY to confirm: " c; [ "$c" = "DESTROY" ] || exit 1
               FSID=$(grep fsid /etc/ceph/ceph.conf 2>/dev/null|awk '{print $3}')
               cephadm rm-cluster --fsid "$FSID" --force 2>/dev/null || true
               rm -rf /var/lib/ceph/* /etc/ceph/* /var/log/ceph/*
               echo "Reset complete. Ready to join or re-bootstrap." ;;
    mount)     P="${2:-/mnt/cephfs}"; mkdir -p "$P"
               ceph-fuse "$P" --client_fs cloudws-fs 2>/dev/null && echo "Mounted at $P" ;;
    unmount)   umount "${2:-/mnt/cephfs}" 2>/dev/null && echo "Unmounted" ;;
    pools)     cephadm shell -- rados df 2>/dev/null ;;
    snapshot)  cephadm shell -- rbd snap create "${2}@snap-$(date +%Y%m%d-%H%M%S)" ;;
    snap-list) cephadm shell -- rbd snap ls "$2" 2>/dev/null ;;
    snap-export) cephadm shell -- rbd export "${2}@${3}" - > "$4" && echo "Exported to $4" ;;
    dashboard) [ -f /etc/ceph/cloudws-join-info.json ] && python3 -c "import json;j=json.load(open('/etc/ceph/cloudws-join-info.json'));print(f'Dashboard: {j[\"dashboard\"]}');print('User: cloudws / Pass: cloudws')" ;;
    nodes)     cephadm shell -- ceph orch host ls 2>/dev/null ;;
    logs)      journalctl -u 'ceph*' --no-pager -n 50 2>/dev/null ;;
    *)         echo "cloudws-ceph: status|bootstrap|join <ip>|reset|mount|unmount|pools|snapshot <img>|snap-list <img>|snap-export <img> <snap> <file>|dashboard|nodes|logs" ;;
esac
'@
Write-UnixFile "system_files/usr/local/bin/cloudws-ceph" $cephCli
Write-Host "    + cloudws-ceph CLI" -ForegroundColor Green
$changes++

$svcScript = "scripts/20-services.sh"
if ((Test-Path $svcScript) -and ((Get-Content $svcScript -Raw) -notmatch 'cloudws-ceph-bootstrap')) {
    $svc = [System.IO.File]::ReadAllText((Resolve-Path $svcScript).Path)
    $svc += "`nsystemctl enable cloudws-ceph-bootstrap.service 2>/dev/null || true`n"
    Write-UnixFile $svcScript $svc
    Write-Host "    ~ 20-services.sh — ceph-bootstrap enabled" -ForegroundColor Green
    $changes++
}

# ═══════════════════════════════════════════════════════════════════════
Write-Host "`n  $changes changes. Push to GitHub? (y/n)" -ForegroundColor Cyan
$doPush = Read-Host
if ($doPush -eq 'y') {
    git add -A; git status --short
    git commit -m "fix: SELinux array + cockpit + GTK + WSL2 + Phosh + Ceph bootstrap (v2.1.2)"
    git push origin main 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) { Write-Host "`n  Pushed. Rebuild: .\cloud-ws.ps1`n" -ForegroundColor Green }
}
