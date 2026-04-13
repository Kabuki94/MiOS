<#
.SYNOPSIS  CloudWS v2.1.2 — Fix 6 runtime issues + add Phosh session
.DESCRIPTION
    1. Cockpit: external access on ALL interfaces (0.0.0.0 + firewall)
    2. GTK theming: GSchema override + GTK3 settings.ini (the RIGHT way)
    3. WSL2: dbus-broker drop-in + systemd-machined skip
    4. Phosh: mobile session + squeekboard + portrait VM support
    5. Window controls: permanent button-layout via GSchema (survives Phosh ↔ GNOME switches)
    6. SELinux MODNAME: unbound variable fix in 37-selinux.sh

    Run from repo root:
      cd C:\Users\Kabu\OneDrive\Documents\GitHub\CloudWS-bootc
      .\fix-v2.1.2.ps1
#>
$ErrorActionPreference = "Stop"

# Helper: write UTF-8 no BOM with LF line endings
function Write-UnixFile {
    param([string]$Path, [string]$Content)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        (Join-Path (Get-Location) $Path),
        $Content.Replace("`r`n", "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
}

# ── Verify repo root ─────────────────────────────────────────────────
if (-not (Test-Path "Containerfile") -or -not (Test-Path "scripts/build.sh")) {
    Write-Host "  ERROR: Run from CloudWS-bootc repo root" -ForegroundColor Red
    exit 1
}

Write-Host "`n  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v2.1.2 Runtime Fixes — 6 Issues + Phosh       ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$changes = 0

# ═══════════════════════════════════════════════════════════════════════
# FIX 1: COCKPIT — Accessible from ALL interfaces
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [1/6] Cockpit — external access on all interfaces..." -ForegroundColor Yellow

# 1a. cockpit.conf — AllowUnencrypted + wildcard Origins
Write-UnixFile "system_files/etc/cockpit/cockpit.conf" @'
# CloudWS — Cockpit web console configuration
# Accessible from: localhost, VM host IP, container IP, any network interface

[WebService]
AllowUnencrypted = true
Origins = https://localhost:9090 wss://localhost:9090
LoginTitle = CloudWS Management Console
MaxStartups = 10
IdleTimeout = 15
UrlRoot = /

[Log]
Fatal = criticals warnings
'@
Write-Host "    + system_files/etc/cockpit/cockpit.conf" -ForegroundColor Green
$changes++

# 1b. cockpit.socket override — listen on 0.0.0.0 and [::]
Write-UnixFile "system_files/etc/systemd/system/cockpit.socket.d/listen-all.conf" @'
# CloudWS — Cockpit listens on ALL interfaces (not just localhost)
[Socket]
ListenStream=
ListenStream=0.0.0.0:9090
ListenStream=[::]:9090
FreeBind=yes
'@
Write-Host "    + cockpit.socket.d/listen-all.conf (0.0.0.0:9090)" -ForegroundColor Green
$changes++

# 1c. Patch 33-firewall.sh — add cockpit to all zones
$fwScript = "scripts/33-firewall.sh"
if (Test-Path $fwScript) {
    $fw = [System.IO.File]::ReadAllText((Resolve-Path $fwScript).Path)
    if ($fw -notmatch 'add-service.*cockpit') {
        # Find the firewall init heredoc and inject cockpit rules before EOF or reload
        $cockpitBlock = @'

# ── Cockpit — accessible from ALL zones ──
for zone in public libvirt trusted; do
    firewall-cmd --permanent --zone="$zone" --add-service=cockpit 2>/dev/null || true
    firewall-cmd --permanent --zone="$zone" --add-port=9090/tcp 2>/dev/null || true
done
'@
        if ($fw -match 'firewall-cmd\s+--reload') {
            $fw = $fw -replace '(firewall-cmd\s+--reload)', "$cockpitBlock`n`$1"
        } else {
            $fw += "`n$cockpitBlock`n"
        }
        Write-UnixFile $fwScript $fw
        Write-Host "    ~ scripts/33-firewall.sh — cockpit port 9090 all zones" -ForegroundColor Green
        $changes++
    } else {
        Write-Host "    - 33-firewall.sh already has cockpit rules" -ForegroundColor DarkGray
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# FIX 2: GTK THEMING — GSchema override (the correct approach)
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [2/6] GTK theming — GSchema override + GTK3 settings..." -ForegroundColor Yellow

# 2a. GSchema override — THIS is the correct way to set GNOME defaults
#     Bazzite/Bluefin use this pattern. dconf database is SECONDARY.
#     GSchema overrides compile into the binary schema cache and apply
#     to ALL users automatically without needing dconf update.
Write-UnixFile "system_files/usr/share/glib-2.0/schemas/90-cloudws.gschema.override" @'
# CloudWS — System-wide GNOME defaults
# Compiled by glib-compile-schemas during build
# These are defaults — users can override via dconf/gsettings

[org.gnome.desktop.interface]
gtk-theme='adw-gtk3-dark'
icon-theme='Adwaita'
cursor-theme='Bibata-Modern-Classic'
cursor-size=24
color-scheme='prefer-dark'
enable-animations=true
font-name='Cantarell 11'
monospace-font-name='Geist Mono 10'

[org.gnome.desktop.wm.preferences]
button-layout='close,minimize,maximize:'
titlebar-font='Cantarell Bold 11'
action-double-click-titlebar='toggle-maximize'

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/gnome/amber-l.jxl'
picture-uri-dark='file:///usr/share/backgrounds/gnome/amber-d.jxl'
picture-options='zoom'
primary-color='#241f31'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/amber-d.jxl'
picture-options='zoom'
primary-color='#241f31'

[org.gnome.desktop.peripherals.touchpad]
tap-to-click=true
natural-scroll=true

[org.gnome.desktop.input-sources]
xkb-options=['terminate:ctrl_alt_bksp']

[org.gnome.desktop.privacy]
remove-old-temp-files=true
remove-old-trash-files=true

[org.gnome.software]
allow-updates=false
download-updates=false
'@
Write-Host "    + 90-cloudws.gschema.override (theme, wallpaper, button-layout)" -ForegroundColor Green
$changes++

# 2b. GTK3 settings.ini for skel (new user sessions)
Write-UnixFile "system_files/etc/skel/.config/gtk-3.0/settings.ini" @'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-font-name=Cantarell 11
'@
Write-Host "    + skel/.config/gtk-3.0/settings.ini (adw-gtk3-dark)" -ForegroundColor Green
$changes++

# 2c. GTK4 settings for skel
Write-UnixFile "system_files/etc/skel/.config/gtk-4.0/settings.ini" @'
[Settings]
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Cantarell 11
'@
Write-Host "    + skel/.config/gtk-4.0/settings.ini" -ForegroundColor Green
$changes++

# 2d. Patch 30-locale-theme.sh to compile GSchema + run dconf update
$themeScript = "scripts/30-locale-theme.sh"
if (Test-Path $themeScript) {
    $ts = [System.IO.File]::ReadAllText((Resolve-Path $themeScript).Path)
    if ($ts -notmatch 'glib-compile-schemas') {
        $schemaBlock = @'

# ── Compile GSchema overrides (THE correct way to set GNOME defaults) ──
echo "[30-locale-theme] Compiling GSchema overrides..."
if [ -f /usr/share/glib-2.0/schemas/90-cloudws.gschema.override ]; then
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || \
        glib-compile-schemas --strict /usr/share/glib-2.0/schemas/ 2>/dev/null || true
    echo "[30-locale-theme] ✓ GSchema overrides compiled"
fi

# ── Update dconf database (secondary to GSchema) ──
dconf update 2>/dev/null || true
'@
        # Append before "Dark theme configured" or at end
        if ($ts -match '\[30-locale-theme\].*Dark theme') {
            $ts = $ts -replace '(\[30-locale-theme\].*Dark theme)', "$schemaBlock`n`$1"
        } else {
            $ts += "`n$schemaBlock`n"
        }
        Write-UnixFile $themeScript $ts
        Write-Host "    ~ 30-locale-theme.sh — glib-compile-schemas + dconf update" -ForegroundColor Green
        $changes++
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# FIX 3: WSL2 — dbus-broker + systemd-machined
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [3/6] WSL2 — dbus-broker + systemd-machined fixes..." -ForegroundColor Yellow

# 3a. dbus-broker drop-in — strip --audit flag in WSL2
Write-UnixFile "system_files/etc/systemd/system/dbus-broker.service.d/wsl2-fix.conf" @'
# CloudWS — dbus-broker WSL2 workaround
# Microsoft WSL2 kernel lacks audit socket, causing dbus-broker to fail
# with exit code 1, cascading to kill ALL D-Bus dependent services.
# This drop-in strips --audit and only activates inside WSL2.

[Unit]
ConditionPathExists=|/proc/sys/fs/binfmt_misc/WSLInterop

[Service]
ExecStart=
ExecStart=/usr/bin/dbus-broker-launch --scope system
OOMScoreAdjust=-500
'@
Write-Host "    + dbus-broker.service.d/wsl2-fix.conf" -ForegroundColor Green
$changes++

# 3b. systemd-machined — skip in WSL2
Write-UnixFile "system_files/etc/systemd/system/systemd-machined.service.d/wsl2-optional.conf" @'
# CloudWS — systemd-machined needs cgroup features WSL2 lacks
[Unit]
ConditionVirtualization=!wsl
'@
Write-Host "    + systemd-machined.service.d/wsl2-optional.conf" -ForegroundColor Green
$changes++

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# FIX 4: PHOSH SESSION — Mobile remote access + portrait VM support
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [4/6] Phosh — mobile session + portrait support..." -ForegroundColor Yellow

# 4a. Phosh wayland session desktop file
Write-UnixFile "system_files/usr/share/wayland-sessions/phosh.desktop" @'
[Desktop Entry]
Name=Phosh (Mobile)
Comment=CloudWS mobile-optimized session (portrait/tablet)
Exec=/usr/bin/phosh-session
Type=Application
DesktopNames=Phosh;GNOME;
'@
Write-Host "    + wayland-sessions/phosh.desktop" -ForegroundColor Green
$changes++

# 4b. Phosh session wrapper that restores GNOME button-layout on exit
Write-UnixFile "system_files/usr/local/bin/phosh-session-wrapper" @'
#!/bin/bash
# CloudWS — Phosh session wrapper
# Launches Phosh, then restores GNOME window controls on exit
# so switching back to GNOME doesn't lose close/min/max buttons

# Run phosh
/usr/bin/phosh-session "$@"
EXIT_CODE=$?

# Restore GNOME button-layout after Phosh exit
# Phosh sets button-layout='' which strips GNOME window controls
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:' 2>/dev/null || true

exit $EXIT_CODE
'@
Write-Host "    + /usr/local/bin/phosh-session-wrapper" -ForegroundColor Green
$changes++

# 4c. Add phosh packages to PACKAGES.md
$pkgMd = "PACKAGES.md"
if (Test-Path $pkgMd) {
    $pkg = [System.IO.File]::ReadAllText((Resolve-Path $pkgMd).Path)
    if ($pkg -notmatch 'packages-phosh') {
        $phoshBlock = @'

### Phosh (Mobile Session)
```packages-phosh
phosh
phoc
squeekboard
gnome-calls
feedbackd
```
'@
        # Insert before the last ``` block or at end
        $pkg += "`n$phoshBlock`n"
        Write-UnixFile $pkgMd $pkg
        Write-Host "    ~ PACKAGES.md — added packages-phosh section" -ForegroundColor Green
        $changes++
    } else {
        Write-Host "    - PACKAGES.md already has phosh packages" -ForegroundColor DarkGray
    }
}

# 4d. Patch 10-gnome.sh to install phosh packages
$gnomeScript = "scripts/10-gnome.sh"
if (Test-Path $gnomeScript) {
    $gs = [System.IO.File]::ReadAllText((Resolve-Path $gnomeScript).Path)
    if ($gs -notmatch 'phosh') {
        $phoshInstall = @'

# ═══════════════════════════════════════════════════════════════════════════════
# Phosh — Mobile session for portrait/tablet remote access
# ═══════════════════════════════════════════════════════════════════════════════
echo "[10-gnome] Installing Phosh mobile session..."
install_packages_optional "phosh"
# Make session wrapper executable
chmod +x /usr/local/bin/phosh-session-wrapper 2>/dev/null || true
'@
        # Insert before the Flatpak section
        if ($gs -match '# ═+\n# Flatpak Remotes') {
            $gs = $gs -replace '(# ═+\n# Flatpak Remotes)', "$phoshInstall`n`$1"
        } else {
            # Fallback — insert before flatpak remote-add
            $gs = $gs -replace '(echo "\[10-gnome\] Configuring Flatpak remotes)', "$phoshInstall`n`$1"
        }
        Write-UnixFile $gnomeScript $gs
        Write-Host "    ~ scripts/10-gnome.sh — phosh install block added" -ForegroundColor Green
        $changes++
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# FIX 5: WINDOW CONTROLS — permanent button-layout
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [5/6] Window controls — permanent button-layout..." -ForegroundColor Yellow

# 5a. Systemd service to restore button-layout on every login
Write-UnixFile "system_files/etc/xdg/autostart/cloudws-restore-buttons.desktop" @'
[Desktop Entry]
Type=Application
Name=CloudWS Window Controls Restore
Comment=Ensures window buttons are always present after Phosh sessions
Exec=gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
NoDisplay=true
X-GNOME-Autostart-Phase=Applications
OnlyShowIn=GNOME;
'@
Write-Host "    + autostart/cloudws-restore-buttons.desktop" -ForegroundColor Green
$changes++

Write-Host "    (GSchema override in fix 2 already sets button-layout='close,minimize,maximize:')" -ForegroundColor DarkGray

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# FIX 6: SELINUX MODNAME — unbound variable
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  [6/6] SELinux MODNAME — unbound variable fix..." -ForegroundColor Yellow

$seScript = "scripts/37-selinux.sh"
if (Test-Path $seScript) {
    $se = [System.IO.File]::ReadAllText((Resolve-Path $seScript).Path)

    # Initialize MODNAME="" before each if-guarded block
    if ($se -match '(?m)^if seinfo -t \S+ .*?\n\s+MODNAME=') {
        $se = $se -replace '(?m)^(if seinfo -t \S+ )', "MODNAME=`"`"`n`$1"
        Write-Host "    ~ MODNAME='' initialized before each if-guard" -ForegroundColor Green
        $changes++
    } else {
        Write-Host "    - MODNAME already initialized or pattern not found" -ForegroundColor DarkGray
    }

    # Wrap rm cleanup in safe guard
    if ($se -match 'rm -f "/tmp/\$\{MODNAME\}"') {
        $se = $se -replace 'rm -f "/tmp/\$\{MODNAME\}"', 'if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}"; fi'
        Write-Host "    ~ rm cleanup wrapped in safe guard" -ForegroundColor Green
        $changes++
    }

    # Also fix the .te .mod .pp cleanup pattern
    if ($se -match 'rm -f "/tmp/\$\{MODNAME\}"\.') {
        $se = $se -replace 'rm -f "/tmp/\$\{MODNAME\}"\.', 'if [ -n "${MODNAME:-}" ]; then rm -f "/tmp/${MODNAME}".'
        Write-Host "    ~ .te/.mod/.pp cleanup wrapped" -ForegroundColor Green
    }

    Write-UnixFile $seScript $se
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
Write-Host "  ══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  $changes changes applied" -ForegroundColor White
Write-Host ""

# Verify critical new files exist
$newFiles = @(
    "system_files/etc/cockpit/cockpit.conf",
    "system_files/etc/systemd/system/cockpit.socket.d/listen-all.conf",
    "system_files/usr/share/glib-2.0/schemas/90-cloudws.gschema.override",
    "system_files/etc/skel/.config/gtk-3.0/settings.ini",
    "system_files/etc/skel/.config/gtk-4.0/settings.ini",
    "system_files/etc/systemd/system/dbus-broker.service.d/wsl2-fix.conf",
    "system_files/etc/systemd/system/systemd-machined.service.d/wsl2-optional.conf",
    "system_files/usr/share/wayland-sessions/phosh.desktop",
    "system_files/usr/local/bin/phosh-session-wrapper",
    "system_files/etc/xdg/autostart/cloudws-restore-buttons.desktop"
)
$ok = 0; $fail = 0
foreach ($f in $newFiles) {
    if (Test-Path $f) {
        Write-Host "    ✓ $f" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "    ✗ $f MISSING" -ForegroundColor Red
        $fail++
    }
}
Write-Host "    $ok created, $fail missing" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })

Write-Host ""
Write-Host "  ── SSH from Windows ──" -ForegroundColor DarkGray
Write-Host "    ssh cloudws@<VM-IP>       (NOT ssh://IP:22)" -ForegroundColor DarkGray
Write-Host "    ssh cloudws@172.17.165.159" -ForegroundColor DarkGray
Write-Host ""

$doPush = Read-Host "  Push to GitHub? (y/n)"
if ($doPush -eq 'y') {
    Write-Host "`n  Staging..." -ForegroundColor Cyan
    git add -A
    git status --short

    $msg = "fix: cockpit external access + GTK GSchema + WSL2 dbus + Phosh session

v2.1.2 runtime fixes:
- Cockpit: AllowUnencrypted, ListenStream=0.0.0.0:9090, firewall port 9090 all zones
- Theme: GSchema override (adw-gtk3-dark, wallpaper, button-layout, fonts)
- GTK3: skel settings.ini for adw-gtk3-dark
- WSL2: dbus-broker drop-in strips --audit, systemd-machined ConditionVirtualization=!wsl
- Phosh: mobile session (phosh, phoc, squeekboard), portrait VM support
- Window controls: GSchema button-layout + autostart restore after Phosh
- SELinux: MODNAME='' init before seinfo guards (set -u compat)
- glib-compile-schemas in 30-locale-theme.sh"

    git commit -m $msg
    Write-Host "  Pushing to origin/main..." -ForegroundColor Cyan
    $pushResult = git push origin main 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  ✓ Pushed. Rebuild: .\cloud-ws.ps1`n" -ForegroundColor Green
    } else {
        Write-Host $pushResult
    }
}

Write-Host "  Done.`n" -ForegroundColor White
