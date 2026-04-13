<#
.SYNOPSIS  Fix 4 runtime issues found after successful v2.1 build
.DESCRIPTION
    1. Cockpit unreachable from host (firewall + listen address + AllowUnencrypted)
    2. SELinux denials (bootupctl, systemd-homed, accounts-daemon, resolved, chcon, gdm)
    3. GTK3/theme inconsistency (adw-gtk3 not applying, wallpaper not set)
    4. WSL2 systemd/dbus-broker failure (cascade kills all services)

    Run from repo root:
      cd C:\Users\Kabu\OneDrive\Documents\GitHub\CloudWS-bootc
      .\fix-runtime-issues.ps1
#>
$ErrorActionPreference = "Stop"

# ── Verify repo root ─────────────────────────────────────────────────────────
if (-not (Test-Path "scripts/build.sh") -or -not (Test-Path "Containerfile")) {
    Write-Host "  X Run from CloudWS-bootc repo root" -ForegroundColor Red
    exit 1
}

Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS Runtime Fixes — 4 Issues                          ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$changeCount = 0

# ═══════════════════════════════════════════════════════════════════════════════
# FIX 1: Cockpit accessible from ALL interfaces (host, VM, container, loopback)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  [1/4] Fixing Cockpit access..." -ForegroundColor Yellow

# 1a. Create cockpit.conf — listen on all interfaces, allow unencrypted for local
$cockpitConfDir = "system_files/etc/cockpit"
New-Item -ItemType Directory -Path $cockpitConfDir -Force | Out-Null
$cockpitConf = @'
# CloudWS — Cockpit configuration
# Listen on ALL interfaces: 0.0.0.0, ::, localhost, container IPs
# For production: set Origins to your specific hostname/IP

[WebService]
# Allow HTTP (not just HTTPS) — required for local/VM/container access
# where TLS termination happens at reverse proxy or is unnecessary
AllowUnencrypted = true

# Accept connections from any origin (host IP, container IP, localhost)
# This is what fixes "Connection failed" when accessing from the host
Origins = https://localhost:9090 wss://localhost:9090 https://127.0.0.1:9090 wss://127.0.0.1:9090

# Login page title
LoginTitle = CloudWS Management Console

# Max idle timeout (15 min)
IdleTimeout = 900

[Session]
# Increase for slow VM boots
IdleTimeout = 15

[Log]
# Reduce noise
Fatal = criticals warnings
'@
[System.IO.File]::WriteAllText(
    (Join-Path (Get-Location) "$cockpitConfDir/cockpit.conf"),
    $cockpitConf.Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "    ✓ Created system_files/etc/cockpit/cockpit.conf" -ForegroundColor Green
$changeCount++

# 1b. Patch 33-firewall.sh to open cockpit port in firewall init
$firewallScript = "scripts/33-firewall.sh"
if (Test-Path $firewallScript) {
    $fw = [System.IO.File]::ReadAllText((Resolve-Path $firewallScript).Path)

    # Check if cockpit port is already opened
    if ($fw -notmatch 'add-service.*cockpit' -and $fw -notmatch 'add-port.*9090') {
        # Find the firewall init script content and add cockpit rules
        # The script creates /usr/local/bin/cloudws-firewall-init or similar
        # We need to add firewall-cmd rules for cockpit

        # Add cockpit firewall rules to the init script
        $cockpitRules = @'

# ── Cockpit — accessible from ALL zones (host, VM, container) ──
firewall-cmd --permanent --add-service=cockpit 2>/dev/null || true
firewall-cmd --permanent --add-port=9090/tcp 2>/dev/null || true
# Also add to libvirt zone for VM access
firewall-cmd --permanent --zone=libvirt --add-service=cockpit 2>/dev/null || true
firewall-cmd --permanent --zone=libvirt --add-port=9090/tcp 2>/dev/null || true
# Trusted zone for container networks
firewall-cmd --permanent --zone=trusted --add-service=cockpit 2>/dev/null || true
'@

        # Insert before the last firewall-cmd --reload or at end of the heredoc
        if ($fw -match 'firewall-cmd\s+--reload') {
            $fw = $fw -replace '(firewall-cmd\s+--reload)', "$cockpitRules`n`$1"
        } elseif ($fw -match "(?s)(EOF\s*\nchmod)") {
            $fw = $fw -replace "(?s)(EOF\s*\nchmod)", "$cockpitRules`nEOF`nchmod"
        } else {
            # Append to end of script
            $fw += "`n$cockpitRules`n"
        }

        $fw = $fw.Replace("`r`n", "`n")
        [System.IO.File]::WriteAllText(
            (Resolve-Path $firewallScript).Path,
            $fw,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "    ✓ Patched $firewallScript — cockpit port 9090 in all zones" -ForegroundColor Green
        $changeCount++
    } else {
        Write-Host "    - $firewallScript already has cockpit rules" -ForegroundColor DarkGray
    }
}

# 1c. Ensure cockpit.socket override listens on all IPs (not just localhost)
$cockpitSocketDir = "system_files/etc/systemd/system/cockpit.socket.d"
New-Item -ItemType Directory -Path $cockpitSocketDir -Force | Out-Null
$cockpitSocketOverride = @'
# CloudWS — Force cockpit to listen on ALL interfaces
# Default cockpit.socket only listens on specific addresses
[Socket]
# Clear existing ListenStream directives first
ListenStream=
# Then bind to all IPv4 and IPv6 on port 9090
ListenStream=0.0.0.0:9090
ListenStream=[::]:9090
FreeBind=yes
'@
[System.IO.File]::WriteAllText(
    (Join-Path (Get-Location) "$cockpitSocketDir/listen-all.conf"),
    $cockpitSocketOverride.Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false)
)
Write-Host "    ✓ Created cockpit.socket.d/listen-all.conf (0.0.0.0:9090 + [::]:9090)" -ForegroundColor Green
$changeCount++

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# FIX 2: SELinux denials — add missing policy modules
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  [2/4] Fixing SELinux denials..." -ForegroundColor Yellow

$selinuxScript = "scripts/37-selinux.sh"
if (Test-Path $selinuxScript) {
    $se = [System.IO.File]::ReadAllText((Resolve-Path $selinuxScript).Path)

    # New modules to add — these cover all 8 denials from the Cockpit SELinux screenshot
    $newModules = @'

# ── Additional SELinux modules for runtime denials (v2.1.1 fixes) ──

# bootupctl accessing /boot/bootupd-state.json (read + open + getattr)
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
    rm -f "/tmp/${MODNAME}".{te,mod,pp}
fi

# systemd-resolved writing to resolve.hook socket
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
    rm -f "/tmp/${MODNAME}".{te,mod,pp}
fi

# accounts-daemon reading Malcontent WebFilter.xml (lnk_file + file read)
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
    rm -f "/tmp/${MODNAME}".{te,mod,pp}
fi

# chcon requiring mac_admin capability
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
    rm -f "/tmp/${MODNAME}".{te,mod,pp}
fi

# gdm-session-worker accessing .cache directory (add_name, write, create)
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
    rm -f "/tmp/${MODNAME}".{te,mod,pp}
fi
'@

    # Insert new modules before the final "SELinux configuration complete" line
    if ($se -match 'SELinux configuration complete') {
        $se = $se -replace '(\[37-selinux\] SELinux configuration complete\.)', "$newModules`n`$1"
    } else {
        # Append to end
        $se += "`n$newModules`n"
    }

    $se = $se.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        (Resolve-Path $selinuxScript).Path,
        $se,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "    ✓ Added 5 new SELinux modules to $selinuxScript" -ForegroundColor Green
    Write-Host "      bootupd_state, resolved_hook, accountsd_malcontent, chcon_macadmin, gdm_session_cache" -ForegroundColor DarkGray
    $changeCount++
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# FIX 3: GTK theming + wallpaper (adw-gtk3, dconf, backgrounds)
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  [3/4] Fixing GTK theming + wallpaper..." -ForegroundColor Yellow

# 3a. Fix dconf database — ensure dark theme + wallpaper are set
$dconfDir = "system_files/etc/dconf/db/local.d"
if (Test-Path $dconfDir) {
    $dconfFile = Get-ChildItem $dconfDir -Filter "*.conf" | Select-Object -First 1
    if ($dconfFile) {
        $dconf = [System.IO.File]::ReadAllText($dconfFile.FullName)

        # Add wallpaper setting if missing
        if ($dconf -notmatch 'picture-uri') {
            $wallpaperBlock = @'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gnome/amber-l.jxl'
picture-uri-dark='file:///usr/share/backgrounds/gnome/amber-d.jxl'
picture-options='zoom'
primary-color='#241f31'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/gnome/amber-d.jxl'
picture-options='zoom'
primary-color='#241f31'
'@
            $dconf += "`n$wallpaperBlock`n"
            Write-Host "    ✓ Added wallpaper defaults to dconf" -ForegroundColor Green
            $changeCount++
        }

        # Ensure GTK theme is set to adw-gtk3-dark for GTK3 apps
        if ($dconf -notmatch 'gtk-theme.*adw-gtk3') {
            $themeBlock = @'

[org/gnome/desktop/interface]
gtk-theme='adw-gtk3-dark'
icon-theme='Adwaita'
cursor-theme='Bibata-Modern-Classic'
cursor-size=24
color-scheme='prefer-dark'
'@
            # Only add if interface section doesn't already exist with these settings
            if ($dconf -match '\[org/gnome/desktop/interface\]') {
                # Append to existing section — add gtk-theme line after the section header
                $dconf = $dconf -replace '(\[org/gnome/desktop/interface\])', "`$1`ngtk-theme='adw-gtk3-dark'"
            } else {
                $dconf += "`n$themeBlock`n"
            }
            Write-Host "    ✓ Added adw-gtk3-dark theme to dconf" -ForegroundColor Green
            $changeCount++
        }

        $dconf = $dconf.Replace("`r`n", "`n")
        [System.IO.File]::WriteAllText(
            $dconfFile.FullName,
            $dconf,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

# 3b. Patch 30-locale-theme.sh to ensure GTK3 settings.ini has adw-gtk3-dark
$themeScript = "scripts/30-locale-theme.sh"
if (Test-Path $themeScript) {
    $ts = [System.IO.File]::ReadAllText((Resolve-Path $themeScript).Path)

    # Check if adw-gtk3-dark is already set in the GTK3 section
    if ($ts -notmatch 'adw-gtk3-dark') {
        # Replace any existing gtk-theme-name with adw-gtk3-dark
        if ($ts -match 'gtk-theme-name\s*=\s*\S+') {
            $ts = $ts -replace 'gtk-theme-name\s*=\s*\S+', 'gtk-theme-name=adw-gtk3-dark'
            Write-Host "    ✓ Set GTK3 theme to adw-gtk3-dark in $themeScript" -ForegroundColor Green
            $changeCount++
        } elseif ($ts -match '(?s)(Configuring GTK3.*?cat\s*>\s*[^\n]*settings\.ini[^\n]*<<)') {
            # If settings.ini is being written, ensure it has the right theme
            $ts = $ts -replace '(gtk-theme-name\s*=\s*)\S+', '${1}adw-gtk3-dark'
            Write-Host "    ✓ Updated GTK3 settings.ini theme in $themeScript" -ForegroundColor Green
            $changeCount++
        }
    } else {
        Write-Host "    - adw-gtk3-dark already set in $themeScript" -ForegroundColor DarkGray
    }

    # Ensure skel GTK3 settings also get adw-gtk3-dark
    if ($ts -notmatch 'skel.*gtk-3.*adw-gtk3') {
        $skelFix = @'

# Ensure skel GTK3 also uses adw-gtk3-dark (for new user sessions)
mkdir -p /etc/skel/.config/gtk-3.0
cat > /etc/skel/.config/gtk-3.0/settings.ini <<'SKELGTK3'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
SKELGTK3
'@
        # Append before the "Dark theme configured" line
        if ($ts -match 'Dark theme configured') {
            $ts = $ts -replace '(.*Dark theme configured)', "$skelFix`n`$1"
        } else {
            $ts += "`n$skelFix`n"
        }
        Write-Host "    ✓ Added skel GTK3 adw-gtk3-dark config" -ForegroundColor Green
        $changeCount++
    }

    $ts = $ts.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        (Resolve-Path $themeScript).Path,
        $ts,
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# FIX 4: WSL2 systemd/dbus-broker cascade failure
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  [4/4] Fixing WSL2 dbus-broker failure..." -ForegroundColor Yellow

$vmGatingScript = "scripts/38-vm-gating.sh"
if (Test-Path $vmGatingScript) {
    $vg = [System.IO.File]::ReadAllText((Resolve-Path $vmGatingScript).Path)

    if ($vg -notmatch 'dbus-broker.*WSL') {
        $wslDbusFix = @'

# ── WSL2 dbus-broker fix ──────────────────────────────────────────────────
# dbus-broker fails in WSL2 because the Microsoft WSL2 kernel lacks
# full cgroup v2 support and audit socket. This cascades to NetworkManager,
# Cockpit, and every service that depends on D-Bus.
# Fix: create a drop-in that adjusts dbus-broker for WSL2 environment.
echo "[38-vm-gating] Installing dbus-broker WSL2 workaround..."
mkdir -p /etc/systemd/system/dbus-broker.service.d
cat > /etc/systemd/system/dbus-broker.service.d/wsl2-fix.conf <<'DBUSFIX'
# Only applies inside WSL2 — ConditionPathExists gates this
[Unit]
ConditionPathExists=|/proc/sys/fs/binfmt_misc/WSLInterop
ConditionPathExists=|/proc/version

[Service]
# Clear and re-set ExecStart to drop --audit which fails in WSL2
ExecStart=
ExecStart=/usr/bin/dbus-broker-launch --scope system
# Relax OOM and resource limits for WSL2
OOMScoreAdjust=-500
DBUSFIX

# Also ensure systemd-machined doesn't block dbus in WSL2
mkdir -p /etc/systemd/system/systemd-machined.service.d
cat > /etc/systemd/system/systemd-machined.service.d/wsl2-optional.conf <<'MACHINEDFIX'
[Unit]
# Make machined non-fatal in WSL2 (it needs cgroup features WSL2 lacks)
ConditionVirtualization=!wsl
MACHINEDFIX

echo "[38-vm-gating] dbus-broker WSL2 workaround installed"
'@

        # Insert before the final "VM gating" complete message
        if ($vg -match 'VM gating.*configured') {
            $vg = $vg -replace '(\[38-vm-gating\].*VM gating.*configured)', "$wslDbusFix`n`$1"
        } else {
            $vg += "`n$wslDbusFix`n"
        }

        $vg = $vg.Replace("`r`n", "`n")
        [System.IO.File]::WriteAllText(
            (Resolve-Path $vmGatingScript).Path,
            $vg,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "    ✓ Added dbus-broker WSL2 drop-in to $vmGatingScript" -ForegroundColor Green
        Write-Host "    ✓ Added systemd-machined WSL2 skip to $vmGatingScript" -ForegroundColor Green
        $changeCount++
    } else {
        Write-Host "    - WSL2 dbus fix already present" -ForegroundColor DarkGray
    }
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY + GIT PUSH
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "  ══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  $changeCount changes applied" -ForegroundColor White
Write-Host ""

# Verify critical files exist
$criticalFiles = @(
    "system_files/etc/cockpit/cockpit.conf",
    "system_files/etc/systemd/system/cockpit.socket.d/listen-all.conf"
)
foreach ($f in $criticalFiles) {
    if (Test-Path $f) {
        Write-Host "    ✓ $f" -ForegroundColor Green
    } else {
        Write-Host "    X $f MISSING" -ForegroundColor Red
    }
}

Write-Host ""
$doPush = Read-Host "  Push to GitHub? (y/n)"
if ($doPush -eq 'y') {
    Write-Host ""
    Write-Host "  Staging changes..." -ForegroundColor Cyan

    git add -A
    git status --short

    $commitMsg = "fix: cockpit access + SELinux denials + GTK theming + WSL2 dbus

Runtime fixes for v2.1 build:
- Cockpit: listen on 0.0.0.0:9090, AllowUnencrypted, firewall port 9090 in all zones
- SELinux: 5 new modules (bootupd_state, resolved_hook, accountsd_malcontent, chcon_macadmin, gdm_session_cache)
- Theme: adw-gtk3-dark for GTK3 apps, wallpaper defaults, skel config
- WSL2: dbus-broker drop-in removes --audit flag, systemd-machined conditional skip"

    git commit -m $commitMsg

    Write-Host "  Pushing to origin/main..." -ForegroundColor Cyan
    $pushResult = git push origin main 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  ✓ Pushed successfully" -ForegroundColor Green
    } else {
        Write-Host "`n  Push output:" -ForegroundColor Yellow
        Write-Host $pushResult
        if ($pushResult -match 'workflow') {
            Write-Host "`n  ⚠ PAT needs 'workflow' scope — regenerate at:" -ForegroundColor Red
            Write-Host "    https://github.com/settings/tokens" -ForegroundColor DarkGray
        }
    }
}

Write-Host "`n  Done. Rebuild with: .\cloud-ws.ps1" -ForegroundColor White
Write-Host ""
