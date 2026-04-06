<#
.SYNOPSIS
    CloudWS v1.2 — Cloud Workstation OS Builder (Windows)

.DESCRIPTION
    All OS configuration lives in standalone bash scripts (scripts/) and config
    overlays (system_files/). This script handles ONLY:
      - Pre-build questions (user, pass, LUKS, registry)
      - Dedicated Podman builder machine lifecycle
      - Username/password injection into 99-overrides.sh
      - Containerfile build execution
      - Post-build rechunking
      - Target serialization (RAW, VHDX, WSL, ISO)
      - Auto-deploy to Hyper-V (Gen2 VM with Enhanced Session)
      - Auto-deploy to WSL2 (with .wslconfig generation)
      - Registry push with authentication

    For Linux-native builds: use the Justfile (just build, just iso, just push)

    FIXES in v1.2:
      - Hyper-V auto-deploy with Enhanced Session (HvSocket)
      - WSL2 auto-deploy with .wslconfig (fixed memory prevents order-7 panics)
      - ISO builds mount iso.toml for kickstart injection
      - pmcd/pmlogger removed from service enables (only pmproxy installed)
      - fapolicyd SELinux policy targets xdm_var_run_t (was xdm_t)
      - New accountsd_homed SELinux policy module
      - WSL2 mask list: +auditd, +audit-rules, +bootloader-update, +usbguard
      - Mount unit permissions fixed (chmod 644)
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
$v = Get-Content "VERSION" -ErrorAction SilentlyContinue; $Version = if ($v) { $v.Trim() } else { "1.2.0" }
$ImageName      = "cloudws"
$ImageTag       = "latest"
$DefUser        = "cloudws"
$DefPass        = "cloudws"
$DefRegistry    = "ghcr.io/kabuki94/cloudws-bootc"
$BuilderMachine = "cloudws-builder"
$LocalImage     = "localhost/${ImageName}:${ImageTag}"
$OutputFolder   = Join-Path $PWD "cloudws-deploy-out"
$BIBImage       = "quay.io/centos-bootc/bootc-image-builder:latest"
$RechunkImage   = "quay.io/centos-bootc/centos-bootc:stream10"
$Timeout        = 30

$RawImg         = Join-Path $OutputFolder "cloudws-bootable.raw"
$TargetVhdx     = Join-Path $OutputFolder "cloudws-hyperv.vhdx"
$TargetWsl      = Join-Path $OutputFolder "cloudws-wsl.tar"
$TargetIso      = Join-Path $OutputFolder "cloudws-installer.iso"

# ══════════════════════════════════════════════════════════════════════════════
#  UI HELPERS
# ══════════════════════════════════════════════════════════════════════════════
function Write-Banner { param([string]$T) $w=78; Write-Host "`n$("═"*$w)" -ForegroundColor Cyan; Write-Host ("  $T") -ForegroundColor Cyan; Write-Host "$("═"*$w)`n" -ForegroundColor Cyan }
function Write-Phase { param([string]$N,[string]$L) Write-Host "`n  [$N] $L" -ForegroundColor Yellow; Write-Host "  $("─"*70)" -ForegroundColor DarkGray }
function Write-Step  { param([string]$M) Write-Host "      » $M" -ForegroundColor DarkCyan }
function Write-OK    { param([string]$M) Write-Host "      ✓ $M" -ForegroundColor Green }
function Write-Warn  { param([string]$M) Write-Host "      ⚠ $M" -ForegroundColor Yellow }
function Write-Fatal { param([string]$M) Write-Host "`n  ✗ FATAL: $M" -ForegroundColor Red; exit 1 }
function Get-FileSize { param([string]$P) if(!(Test-Path $P)){return "N/A"} $s=(Get-Item $P).Length; if($s -gt 1GB){"$([math]::Round($s/1GB,2)) GB"}elseif($s -gt 1MB){"$([math]::Round($s/1MB,1)) MB"}else{"$([math]::Round($s/1KB,0)) KB"} }

function Read-Timed {
    param([string]$Prompt, [string]$Default, [switch]$Secret)
    Write-Host "    $Prompt " -NoNewline -ForegroundColor White
    if ($Secret) { Write-Host "[hidden, ${Timeout}s] " -NoNewline -ForegroundColor DarkGray }
    else { Write-Host "[$Default, ${Timeout}s] " -NoNewline -ForegroundColor DarkGray }
    $sw = [System.Diagnostics.Stopwatch]::StartNew(); $buf = ""
    while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq 'Enter') { Write-Host ""; if($buf){return $buf}else{return $Default} }
            if ($k.Key -eq 'Backspace' -and $buf.Length -gt 0) { $buf = $buf.Substring(0,$buf.Length-1); Write-Host "`b `b" -NoNewline }
            elseif ($k.KeyChar -match '[\x20-\x7E]') { $buf += $k.KeyChar; Write-Host $(if($Secret){"*"}else{$k.KeyChar}) -NoNewline }
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host " (timeout → default)"; return $Default
}

function Clean-BIBTemp {
    Get-ChildItem $OutputFolder -Directory -Filter "image-*" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem $OutputFolder -File -Filter "manifest-*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0: CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Banner "CloudWS v$Version — Cloud Workstation OS Builder"
Write-Phase "0" "Build Configuration (${Timeout}s timeout per question)"

$U = Read-Timed "Username:" $DefUser
$P = Read-Timed "Password:" $DefPass -Secret
$luksIn = Read-Timed "Enable LUKS2 disk encryption? (y/N):" "N"
$UseLuks = $luksIn -match "^[yY]"
$LuksPass = if ($UseLuks) { Read-Timed "LUKS passphrase:" "cloudws" -Secret } else { "" }
$RegistryUrl = Read-Timed "Registry URL:" $DefRegistry
$GhcrImage = "${RegistryUrl}:${ImageTag}"
$RegistryUser = $env:CLOUDWS_GHCR_USER
$RegistryToken = $env:CLOUDWS_GHCR_TOKEN
if (-not $RegistryUser) { $RegistryUser = Read-Timed "Registry username:" "kabuki94" }
if (-not $RegistryToken) { $RegistryToken = Read-Timed "Registry token/PAT:" "" -Secret }

Write-Host ""
Write-OK "User: $U | LUKS: $(if($UseLuks){'Yes'}else{'No'}) | Registry: $GhcrImage"

# ── Validate prerequisites ───────────────────────────────────────────────────
Write-Phase "0.5" "System Validation"
if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null }
try { $pv = & podman --version 2>&1; Write-OK "Podman: $pv" } catch { Write-Fatal "Podman not found" }
$cpu = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$ram = [math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
Write-OK "CPU: $cpu cores | RAM: $ram MB"

foreach ($f in "Containerfile","PACKAGES.md","VERSION","scripts/build.sh","scripts/99-overrides.sh") {
    if (-not (Test-Path $f)) { Write-Fatal "Missing required file: $f — are you in the CloudWS-bootc repo root?" }
}
Write-OK "All repo files present"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 1: PODMAN BUILDER MACHINE
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "1" "Podman Builder Machine"
$ErrorActionPreference = "Continue"

$vmCheck = & podman machine inspect $BuilderMachine 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Step "Creating dedicated '$BuilderMachine' (your default machine is safe)..."
    & podman machine init $BuilderMachine --rootful --cpus $cpu --memory $ram --disk-size 250
}
Write-Step "Starting '$BuilderMachine'..."
& podman machine stop $BuilderMachine 2>$null; Start-Sleep 2
& podman machine start $BuilderMachine
if ($LASTEXITCODE -ne 0) { Write-Fatal "$BuilderMachine failed to start" }

& podman system connection default "${BuilderMachine}-root"
Write-OK "Builder ready: ${BuilderMachine}-root"
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2: INJECT CREDENTIALS & BUILD
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "2" "OCI Container Build"

$ovr = Get-Content "scripts/99-overrides.sh" -Raw
$ovr = $ovr.Replace('INJ_U', $U).Replace('INJ_P', $P)
$ovr | Set-Content "scripts/99-overrides.sh" -NoNewline -Encoding ascii
Write-OK "Credentials injected into 99-overrides.sh"

$t0 = Get-Date
Write-Step "Building OCI image (all $cpu threads)..."
& podman build --no-cache -t $LocalImage .
if ($LASTEXITCODE -ne 0) { Write-Fatal "podman build failed" }

& git checkout scripts/99-overrides.sh 2>$null
if ($LASTEXITCODE -ne 0) {
    $ovr = $ovr.Replace($U, 'INJ_U').Replace($P, 'INJ_P')
    $ovr | Set-Content "scripts/99-overrides.sh" -NoNewline -Encoding ascii
}

$buildMin = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
Write-OK "Image built in $buildMin min → $LocalImage"

# Tag with GHCR ref BEFORE BIB — sets permanent update origin
Write-Step "Tagging as $GhcrImage (sets update origin for bootc)..."
& podman tag $LocalImage $GhcrImage
Write-OK "Update origin set: $GhcrImage"

# Rechunk for optimized Day-2 updates
Write-Step "Rechunking for optimized OCI layers..."
$ErrorActionPreference = "Continue"
& podman run --rm --privileged `
    -v /var/lib/containers/storage:/var/lib/containers/storage `
    $RechunkImage /usr/libexec/bootc-base-imagectl rechunk $LocalImage $LocalImage
$ErrorActionPreference = "Stop"
Write-OK "Rechunk complete"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3: GENERATE DEPLOYMENT TARGETS
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "3" "Generating Deployment Targets"
$ErrorActionPreference = "Continue"

$bibConf = Join-Path $PWD "config\bib.json"
if (-not (Test-Path $bibConf)) { $bibConf = Join-Path $PWD "config\bib.toml" }
$bibConfDest = Join-Path $OutputFolder "bib-config.json"
if ($bibConf -match '\.toml$') { $bibMountPath = "/config.toml" } else { $bibMountPath = "/config.json" }
if (Test-Path $bibConf) {
    Copy-Item $bibConf $bibConfDest -Force
    Write-OK "BIB config: 80 GiB minimum root (mounted as $bibMountPath)"
} else {
    Write-Warn "No BIB config found — disk may auto-size too small!"
    $bibConfDest = $null
}

# iso.toml for kickstart injection during Anaconda ISO builds
$isoToml = Join-Path $PWD "iso.toml"
$hasIsoToml = Test-Path $isoToml
if ($hasIsoToml) { Write-OK "iso.toml found — kickstart will be injected into ISO" }

function Get-BIBArgs {
    param([string]$Type)
    $bibArgs = @(
        "run", "--rm", "-it", "--privileged",
        "--security-opt", "label=type:unconfined_t",
        "-v", "/var/lib/containers/storage:/var/lib/containers/storage",
        "-v", "${OutputFolder}:/output:z"
    )
    if ($bibConfDest -and (Test-Path $bibConfDest)) {
        $bibArgs += @("-v", "${bibConfDest}:${bibMountPath}:ro")
    }
    # Mount iso.toml for Anaconda ISO builds (kickstart injection)
    if ($Type -eq "anaconda-iso" -and $hasIsoToml) {
        $bibArgs += @("-v", "${isoToml}:/config.toml:ro")
    }
    $bibArgs += @($BIBImage, "build", "--type", $Type, "--rootfs", "ext4", $GhcrImage)
    return $bibArgs
}

# ── RAW ──────────────────────────────────────────────────────────────────────
Write-Step "TARGET 1 — RAW disk image..."
& podman @(Get-BIBArgs "raw")
$genRaw = Get-ChildItem $OutputFolder -Filter "disk.raw" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genRaw) { Move-Item $genRaw.FullName $RawImg -Force; Write-OK "RAW: $(Get-FileSize $RawImg)" }
else { Write-Warn "RAW failed" }
Clean-BIBTemp

# ── VHDX ─────────────────────────────────────────────────────────────────────
Write-Step "TARGET 2 — VHD → VHDX (Hyper-V Gen2)..."
& podman @(Get-BIBArgs "vhd")
$genVhd = Get-ChildItem $OutputFolder -Filter "disk.vhd" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genVhd) {
    $vDir = Split-Path $genVhd.FullName -Parent
    & podman run --rm -v "${vDir}:/d:z" docker.io/alpine:latest sh -c "apk add --no-cache qemu-img && qemu-img convert -p -f vpc -O vhdx -o subformat=dynamic /d/$($genVhd.Name) /d/cloudws-hyperv.vhdx"
    if (Test-Path (Join-Path $vDir "cloudws-hyperv.vhdx")) {
        Move-Item (Join-Path $vDir "cloudws-hyperv.vhdx") $TargetVhdx -Force -ErrorAction SilentlyContinue
        Write-OK "VHDX: $(Get-FileSize $TargetVhdx)"
    }
    Remove-Item $genVhd.FullName -Force -ErrorAction SilentlyContinue
} else { Write-Warn "VHD failed" }
Clean-BIBTemp

# ── WSL2 ─────────────────────────────────────────────────────────────────────
Write-Step "TARGET 3 — WSL2 tarball..."
& podman rm wsl-tmp 2>$null
& podman create --name wsl-tmp $LocalImage | Out-Null
& podman export -o $TargetWsl wsl-tmp
& podman rm wsl-tmp | Out-Null
if (Test-Path $TargetWsl) { Write-OK "WSL: $(Get-FileSize $TargetWsl)" }
else { Write-Warn "WSL failed" }

# ── ISO ──────────────────────────────────────────────────────────────────────
Write-Step "TARGET 4 — Anaconda installer ISO..."
& podman @(Get-BIBArgs "anaconda-iso")
$genIso = Get-ChildItem $OutputFolder -Filter "*.iso" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genIso) { Move-Item $genIso.FullName $TargetIso -Force; Write-OK "ISO: $(Get-FileSize $TargetIso)" }
else { Write-Warn "ISO failed" }
Clean-BIBTemp

$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3b: AUTO-DEPLOY (Hyper-V + WSL2)
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "3b" "Auto-Deploy to Hyper-V + WSL2"
$ErrorActionPreference = "Continue"

# ── HYPER-V AUTO-DEPLOY ──────────────────────────────────────────────────────
if (Test-Path $TargetVhdx) {
    Write-Step "Deploying to Hyper-V..."
    $VMName = "CloudWS-OS"
    $VMPath = Join-Path $env:USERPROFILE "Hyper-V\CloudWS"
    $VhdxDest = Join-Path $VMPath "cloudws-hyperv.vhdx"

    try {
        # Remove existing VM if present
        $existing = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Step "Removing existing VM '$VMName'..."
            Stop-VM -Name $VMName -Force -TurnOff -ErrorAction SilentlyContinue
            Remove-VM -Name $VMName -Force
        }

        New-Item -ItemType Directory -Path $VMPath -Force | Out-Null
        Copy-Item $TargetVhdx $VhdxDest -Force

        # Gen2 VM: 8GB fixed RAM, half host CPUs, no dynamic memory
        $cpuCount = [Math]::Max(4, [Math]::Floor((Get-CimInstance Win32_Processor).NumberOfLogicalProcessors / 2))
        $vmRAM = 8GB

        New-VM -Name $VMName -Path $VMPath -Generation 2 -MemoryStartupBytes $vmRAM -VHDPath $VhdxDest | Out-Null
        Set-VM -Name $VMName `
            -ProcessorCount $cpuCount `
            -DynamicMemory:$false `
            -CheckpointType Disabled `
            -AutomaticStartAction Nothing `
            -AutomaticStopAction ShutDown

        # Secure Boot: Microsoft UEFI CA (NOT "Microsoft Windows" — that rejects Linux shim)
        Set-VMFirmware -VMName $VMName -SecureBootTemplate "MicrosoftUEFICertificateAuthority"

        # Enhanced Session via HvSocket (xRDP vsock configured in image)
        Set-VM -Name $VMName -EnhancedSessionTransportType HvSocket

        # Network: Default Switch
        $switch = Get-VMSwitch "Default Switch" -ErrorAction SilentlyContinue
        if ($switch) { Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $switch.Name }

        Write-OK "Hyper-V VM '$VMName' created"
        Write-OK "  CPUs: $cpuCount | RAM: $([Math]::Round($vmRAM / 1GB))GB (fixed) | Enhanced Session: ON"
        Write-OK "  Start: Start-VM -Name '$VMName'"
    } catch {
        Write-Warn "Hyper-V auto-deploy failed: $_"
    }
} else {
    Write-Warn "VHDX not found — skipping Hyper-V auto-deploy"
}

# ── WSL2 AUTO-DEPLOY ─────────────────────────────────────────────────────────
if (Test-Path $TargetWsl) {
    Write-Step "Deploying to WSL2..."
    $WslName = "CloudWS-OS"
    $WslPath = Join-Path $env:USERPROFILE "WSL\CloudWS"

    try {
        $distros = wsl --list --quiet 2>$null
        if ($distros -match $WslName) {
            Write-Step "Removing existing WSL distro '$WslName'..."
            wsl --unregister $WslName 2>$null | Out-Null
        }

        New-Item -ItemType Directory -Path $WslPath -Force | Out-Null
        wsl --import $WslName $WslPath $TargetWsl --version 2
        if ($LASTEXITCODE -ne 0) { throw "WSL import failed" }

        Write-OK "WSL2 distro '$WslName' imported"

        # Generate .wslconfig — fixed memory prevents VMBus order-7 allocation panics
        $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
        $totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
        $wslRAM = [Math]::Max(8, [Math]::Floor($totalRAM / 1GB / 2))
        $wslCPUs = [Math]::Max(4, [Math]::Floor((Get-CimInstance Win32_Processor).NumberOfLogicalProcessors / 2))

        $wslConfig = @'
# CloudWS v1.2 — WSL2 Configuration
# CRITICAL: Fixed memory prevents VMBus order-7 allocation panics
[wsl2]
memory=${wslRAM}GB
processors=${wslCPUs}
swap=8GB
localhostForwarding=true
nestedVirtualization=true
vmIdleTimeout=-1
'@
        $wslConfig = $wslConfig.Replace('${wslRAM}', $wslRAM).Replace('${wslCPUs}', $wslCPUs)

        if (Test-Path $wslConfigPath) {
            $backup = "${wslConfigPath}.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $wslConfigPath $backup
            Write-Step "Backed up existing .wslconfig to $backup"
        }

        $wslConfig | Set-Content $wslConfigPath -Encoding UTF8
        Write-OK ".wslconfig generated: ${wslRAM}GB RAM, $wslCPUs CPUs (fixed allocation)"
        Write-OK "  Run 'wsl --shutdown' then relaunch for .wslconfig to take effect"
    } catch {
        Write-Warn "WSL2 auto-deploy failed: $_"
    }
} else {
    Write-Warn "WSL tarball not found — skipping WSL2 auto-deploy"
}

$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4: REGISTRY PUSH
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "4" "Registry Push → $GhcrImage"
$ErrorActionPreference = "Continue"
$registryHost = ($GhcrImage -split '/')[0]

if ($RegistryToken) {
    Write-Step "Authenticating to $registryHost (via stdin)..."
    $RegistryToken | podman login $registryHost --username $RegistryUser --password-stdin 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warn "Registry login failed — push may fail" }
}

& podman push $GhcrImage 2>&1 | Out-Null
$GhcrOK = $LASTEXITCODE -eq 0
if ($GhcrOK) {
    Write-OK "Pushed to $registryHost"
    if ($registryHost -eq "ghcr.io" -and $RegistryToken) {
        try {
            $pkgName = ($GhcrImage -split '/')[-1] -replace ':.*$',''
            Invoke-RestMethod -Uri "https://api.github.com/user/packages/container/$pkgName" -Method Patch `
                -Headers @{Authorization="Bearer $RegistryToken";Accept="application/vnd.github+json"} `
                -Body '{"visibility":"public"}' -ContentType "application/json" -ErrorAction Stop
            Write-OK "GHCR package set to public"
        } catch { Write-Warn "Could not auto-set public visibility — do it manually: https://github.com/Kabuki94?tab=packages" }
    }
} else { Write-Warn "Push failed — check credentials"; $GhcrOK = $false }
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: CLEANUP & REPORT
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "5" "Cleanup & Report"
$ErrorActionPreference = "Continue"
& podman system connection default podman-machine-default 2>$null
& podman machine stop $BuilderMachine 2>$null
Write-OK "Builder stopped. Your default Podman machine restored."
Write-Step "To remove builder: podman machine rm $BuilderMachine"
$ErrorActionPreference = "Stop"

$total = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
$T1 = Test-Path $RawImg; $T2 = Test-Path $TargetVhdx; $T3 = Test-Path $TargetWsl; $T4 = Test-Path $TargetIso
$color = if ($T1 -and $T2 -and $T3 -and $T4 -and $GhcrOK) { "Green" } else { "Yellow" }

Write-Host "`n  $("═"*78)" -ForegroundColor $color
Write-Host "   CLOUDWS v$Version BUILD COMPLETE (${total} min)" -ForegroundColor $color
Write-Host "  $("═"*78)`n" -ForegroundColor $color

foreach ($t in @(
    @(1,"RAW",$T1,$RawImg,"dd if=cloudws-bootable.raw of=/dev/sdX bs=4M"),
    @(2,"VHDX",$T2,$TargetVhdx,"Hyper-V Gen2 → auto-deployed as 'CloudWS-OS'"),
    @(3,"WSL2",$T3,$TargetWsl,"Auto-imported as 'CloudWS-OS' with .wslconfig"),
    @(4,"ISO",$T4,$TargetIso,"Write to USB with Rufus (ISO mode)"),
    @(5,"Registry",$GhcrOK,$GhcrImage,"sudo bootc switch $GhcrImage")
)) {
    $icon = if($t[2]){"✓"}else{"✗"}; $c = if($t[2]){"Green"}else{"Red"}
    Write-Host "  [$icon] TARGET $($t[0]) — $($t[1])" -ForegroundColor $c
    if($t[2]) { Write-Host "      $($t[3]) ($(Get-FileSize $t[3]))" -ForegroundColor DarkGray; Write-Host "      $($t[4])" -ForegroundColor DarkGray }
    Write-Host ""
}

Write-Host "  Credentials: $U / ****" -ForegroundColor Yellow
Write-Host "  Update origin: $GhcrImage (baked into all disk images)" -ForegroundColor DarkGray
Write-Host "  Terminal:    cloudws --help | cloudws-test --full" -ForegroundColor DarkGray
Write-Host "  Headless:    sudo cloudws-toggle-headless off" -ForegroundColor DarkGray
Write-Host "  Cockpit:     https://localhost:9090" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Hyper-V: Start-VM -Name 'CloudWS-OS' | vmconnect localhost 'CloudWS-OS'" -ForegroundColor Yellow
Write-Host "  WSL2:    wsl -d CloudWS-OS (run 'wsl --shutdown' first for .wslconfig)" -ForegroundColor Yellow
Write-Host ""
