<#
.SYNOPSIS
    CloudWS v1.3 — Cloud Workstation OS Builder (Windows)

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

    FIXES in v1.3:
      - ISO build: only mount iso.toml (not bib config) — BIB crashes with both
      - WSL deploy: robust --unregister (handles UTF-16 output from wsl --list)
      - Dark theme: ADW_DEBUG_COLOR_SCHEME (not GTK_THEME)
      - Fastfetch: injected into .bashrc (not just profile.d)
      - GPU-PV baseline in all images
      - Database stack (MariaDB, PostgreSQL, pgvector, Redis)
      - VM HA (sanlock, libvirt-lock-sanlock)
      - AI post-install framework (cloudws-ai-*)
      - First-boot timezone geolocation
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
$v = Get-Content "VERSION" -ErrorAction SilentlyContinue; $Version = if ($v) { $v.Trim() } else { "1.3.0" }
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
function Get-FileSize { param([string]$P) if(!(Test-Path $P)){return "N/A"} $s=(Get-Item $P).Length; if($s -gt 1GB){"$([math]::Round($s/1GB,2)) GB"}else{"$([math]::Round($s/1MB,2)) MB"} }
function Read-Timed { param([string]$Prompt, [string]$Default, [switch]$Secret)
    if ($Secret) { Write-Host "      $Prompt " -NoNewline -ForegroundColor DarkCyan; Write-Host "[$("*"*$Default.Length)] " -NoNewline -ForegroundColor DarkGray }
    else { Write-Host "      $Prompt " -NoNewline -ForegroundColor DarkCyan; Write-Host "[$Default] " -NoNewline -ForegroundColor DarkGray }
    $sw = [System.Diagnostics.Stopwatch]::StartNew(); $input = ""
    while ($sw.Elapsed.TotalSeconds -lt $Timeout -and -not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 100 }
    if ([Console]::KeyAvailable) { $input = Read-Host }
    if ([string]::IsNullOrWhiteSpace($input)) { $input = $Default }
    return $input
}
function Clean-BIBTemp { Get-ChildItem $OutputFolder -Directory -Filter "image" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }

Write-Banner "CloudWS v$Version — Cloud Workstation OS Builder"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0: CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "0" "Configuration (${Timeout}s timeout per question)"
$U = Read-Timed "Username:" $DefUser
$P = Read-Timed "Password:" $DefPass -Secret
$luksIn = Read-Timed "Enable LUKS encryption? (y/N):" "N"
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

# BIB config — use bib.toml ONLY (bib.json deleted in v1.3 to prevent conflict)
$bibConf = Join-Path $PWD "config\bib.toml"
if (-not (Test-Path $bibConf)) { $bibConf = Join-Path $PWD "config\bib.json" }
$bibConfDest = Join-Path $OutputFolder "bib-config"
if (Test-Path $bibConf) {
    if ($bibConf -match '\.toml$') {
        $bibMountPath = "/config.toml"
        Copy-Item $bibConf "$bibConfDest.toml" -Force
        $bibConfDest = "$bibConfDest.toml"
    } else {
        $bibMountPath = "/config.json"
        Copy-Item $bibConf "$bibConfDest.json" -Force
        $bibConfDest = "$bibConfDest.json"
    }
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
    # FIX v1.3: BIB only supports ONE config file. For ISO, use iso.toml ONLY
    # (it now includes minsize). For other targets, use bib config only.
    if ($Type -eq "anaconda-iso" -and $hasIsoToml) {
        $bibArgs += @("-v", "${isoToml}:/config.toml:ro")
    } elseif ($bibConfDest -and (Test-Path $bibConfDest)) {
        $bibArgs += @("-v", "${bibConfDest}:${bibMountPath}:ro")
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
        # FIX v1.3: Always try --unregister first (wsl --list output is UTF-16
        # and -match comparison silently fails). Ignore errors if not registered.
        Write-Step "Ensuring clean WSL state (unregister if exists)..."
        wsl --unregister $WslName 2>$null | Out-Null
        Start-Sleep 1

        New-Item -ItemType Directory -Path $WslPath -Force | Out-Null
        wsl --import $WslName $WslPath $TargetWsl --version 2
        if ($LASTEXITCODE -ne 0) { throw "WSL import failed" }

        Write-OK "WSL2 distro '$WslName' imported"

        # Generate .wslconfig — fixed memory prevents VMBus order-7 allocation panics
        $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
        $totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
        $wslRAM = [Math]::Max(8, [Math]::Floor($totalRAM / 1GB / 2))
        $wslCPUs = [Math]::Max(4, [Math]::Floor((Get-CimInstance Win32_Processor).NumberOfLogicalProcessors / 2))

        $wslConfig = @"
# CloudWS v1.3 — WSL2 Configuration
# CRITICAL: Fixed memory prevents VMBus order-7 allocation panics
[wsl2]
memory=${wslRAM}GB
processors=${wslCPUs}
swap=8GB
localhostForwarding=true
nestedVirtualization=true
vmIdleTimeout=-1
"@

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
            $pkgName = ($GhcrImage -split '/')[-1] -replace ':.*', ''
            $owner = ($GhcrImage -split '/')[1]
            $headers = @{ Authorization = "Bearer $RegistryToken"; Accept = "application/vnd.github+json" }
            Invoke-RestMethod -Uri "https://api.github.com/user/packages/container/$pkgName/versions" -Headers $headers -Method Get -ErrorAction Stop | Out-Null
            Invoke-RestMethod -Uri "https://api.github.com/user/packages/container/$pkgName" -Headers $headers -Method Patch -Body '{"visibility":"public"}' -ContentType "application/json" -ErrorAction Stop | Out-Null
            Write-OK "Package visibility set to public"
        } catch { Write-Warn "Could not set public (manual: https://github.com/Kabuki94?tab=packages)" }
    }
} else { Write-Warn "Push failed — authenticate manually: podman push $GhcrImage" }

$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: CLEANUP & REPORT
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "5" "Cleanup & Report"
$ErrorActionPreference = "Continue"

# Restore default Podman machine
& podman system connection default "podman-machine-default-root" 2>$null
& podman machine stop $BuilderMachine 2>$null
Write-OK "Restored default Podman machine"

$ErrorActionPreference = "Stop"

# ── Build report ─────────────────────────────────────────────────────────────
Write-Banner "CloudWS v$Version — Build Complete"
$totalMin = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
Write-Host "  Total time: $totalMin min" -ForegroundColor DarkGray
Write-Host ""
$targets = @(
    @{N="OCI Image"; P=$LocalImage; S="(in Podman storage)"},
    @{N="RAW Disk";  P=$RawImg;     S=Get-FileSize $RawImg},
    @{N="VHDX";      P=$TargetVhdx; S=Get-FileSize $TargetVhdx},
    @{N="WSL Tar";   P=$TargetWsl;  S=Get-FileSize $TargetWsl},
    @{N="ISO";       P=$TargetIso;  S=Get-FileSize $TargetIso},
    @{N="Registry";  P=$GhcrImage;  S=if($GhcrOK){"✓ pushed"}else{"⚠ not pushed"}}
)
foreach ($t in $targets) {
    $icon = if ($t.P -eq $LocalImage -or $t.P -eq $GhcrImage) { "✓" } elseif (Test-Path $t.P -ErrorAction SilentlyContinue) { "✓" } else { "✗" }
    $color = if ($icon -eq "✓") { "Green" } else { "Red" }
    Write-Host "    $icon $($t.N): $($t.S)" -ForegroundColor $color
}
Write-Host ""
Write-Host "  Deploy commands:" -ForegroundColor Yellow
Write-Host "    Hyper-V:  Start-VM -Name 'CloudWS-OS'" -ForegroundColor DarkGray
Write-Host "    WSL2:     wsl -d CloudWS-OS" -ForegroundColor DarkGray
Write-Host "    Bare:     dd if=$RawImg of=/dev/sdX bs=4M status=progress" -ForegroundColor DarkGray
Write-Host "    Update:   bootc upgrade (from inside running CloudWS)" -ForegroundColor DarkGray
Write-Host ""
