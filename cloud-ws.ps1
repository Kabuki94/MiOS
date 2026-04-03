<#
.SYNOPSIS
    CloudWS v1.0 — Cloud Workstation OS Build Orchestrator (Windows)
.DESCRIPTION
    Thin orchestrator for building CloudWS on Windows via Podman WSL2 backend.
    All OS configuration lives in standalone bash scripts (scripts/) and config
    overlays (system_files/). This script handles ONLY:
      - Pre-build questions (user, pass, LUKS, registry)
      - Dedicated Podman builder machine lifecycle
      - Username/password injection into 99-overrides.sh
      - Containerfile build execution
      - Post-build rechunking
      - Target serialization (RAW, VHDX, WSL, ISO)
      - Registry push with authentication

    For Linux-native builds: use the Justfile (just build, just iso, just push)
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
$Version        = (Get-Content "VERSION" -ErrorAction SilentlyContinue) ?? "1.0.0"
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
function Get-FileSize { param([string]$P) if(!(Test-Path $P)){"N/A"}else{$b=(Get-Item $P).Length;if($b-gt 1GB){"{0:N2} GB" -f($b/1GB)}elseif($b-gt 1MB){"{0:N2} MB" -f($b/1MB)}else{"{0:N0} KB" -f($b/1KB)}} }

function Read-Timed {
    param([string]$Prompt, [string]$Default, [switch]$Secret)
    $display = if ($Secret) { "****" } else { $Default }
    Write-Host "      $Prompt " -ForegroundColor Cyan -NoNewline
    Write-Host "[default: $display] " -ForegroundColor DarkGray -NoNewline
    Write-Host "(${Timeout}s)" -ForegroundColor DarkGray
    $sw = [System.Diagnostics.Stopwatch]::StartNew(); $buf = ""
    while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            if ($k.Key -eq 'Enter') { break }
            if ($k.Key -eq 'Backspace' -and $buf.Length -gt 0) { $buf=$buf.Substring(0,$buf.Length-1); Write-Host "`b `b" -NoNewline }
            else { $buf += $k.KeyChar; Write-Host $(if($Secret){"*"}else{$k.KeyChar}) -NoNewline }
        }
        Start-Sleep -Milliseconds 50
    }
    Write-Host ""
    if ([string]::IsNullOrWhiteSpace($buf)) { return $Default }
    return $buf
}

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 0: BUILD CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Banner "CLOUDWS v$Version — CLOUD WORKSTATION OS"
Write-Host "  Base     : Fedora Rawhide bootc | GNOME 50 | Wayland-only" -ForegroundColor Gray
Write-Host "  Hardware : AMD / Intel / NVIDIA (auto-detected at boot)" -ForegroundColor Gray
Write-Host "  Targets  : RAW → VHDX → WSL2 → ISO → Registry" -ForegroundColor Gray

Write-Phase "0" "Build Configuration"
Write-Host ""
$U = Read-Timed "CloudWS username:" $DefUser
$P = Read-Timed "CloudWS password:" $DefPass -Secret
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

# ── Validate repo files exist ────────────────────────────────────────────────
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

# Set as active connection for this build session
& podman system connection default "${BuilderMachine}-root"
Write-OK "Builder ready: ${BuilderMachine}-root"
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 2: INJECT CREDENTIALS & BUILD
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "2" "OCI Container Build"

# Inject username/password into 99-overrides.sh (temp copy)
$ovr = Get-Content "scripts/99-overrides.sh" -Raw
$ovr = $ovr.Replace('INJ_U', $U).Replace('INJ_P', $P)
$ovr | Set-Content "scripts/99-overrides.sh" -NoNewline -Encoding ascii
Write-OK "Credentials injected into 99-overrides.sh"

$t0 = Get-Date
Write-Step "Building OCI image (all $cpu threads)..."
& podman build --no-cache -t $LocalImage .
if ($LASTEXITCODE -ne 0) {
    # Restore original overrides before failing
    & git checkout -- scripts/99-overrides.sh 2>$null
    Write-Fatal "Podman build failed"
}
# Restore original overrides (with placeholders)
& git checkout -- scripts/99-overrides.sh 2>$null
$elapsed = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
Write-OK "Image built in ${elapsed} min → $LocalImage"

# ── Rechunk ──────────────────────────────────────────────────────────────────
Write-Step "Rechunking for optimized OCI layers..."
$ErrorActionPreference = "Continue"
& podman run --rm --privileged -v /var/lib/containers/storage:/var/lib/containers/storage $RechunkImage /usr/libexec/bootc-base-imagectl rechunk $LocalImage "${ImageName}:rechunked" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    & podman tag "${ImageName}:rechunked" $LocalImage
    & podman tag "${ImageName}:rechunked" $GhcrImage
    & podman rmi "${ImageName}:rechunked" 2>$null
    Write-OK "Rechunk complete"
} else { Write-Warn "Rechunk failed (non-fatal)" }
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 3: TARGET SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "3" "Generating Deployment Targets"
$ErrorActionPreference = "Continue"

# Helper: clean BIB intermediate dirs after each target
function Clean-BIBTemp {
    Get-ChildItem $OutputFolder -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^(image|qcow2|raw|vpc|bootiso)$" } |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    & podman system prune -f 2>$null | Out-Null
}

# Copy BIB config to output folder (BIB container sees /output)
$bibConf = Join-Path $PWD "config\bib.toml"
if (Test-Path $bibConf) {
    Copy-Item $bibConf (Join-Path $OutputFolder "bib.toml") -Force
    $bibConfigArg = "--config /output/bib.toml"
    Write-OK "BIB config: 80 GiB minimum root filesystem"
} else {
    $bibConfigArg = ""
    Write-Warn "config/bib.toml not found — BIB will auto-size (may be too small!)"
}

# ── RAW ──────────────────────────────────────────────────────────────────────
Write-Step "TARGET 1 — RAW disk image..."
& podman run --rm -it --privileged -v /var/lib/containers/storage:/var/lib/containers/storage -v "${OutputFolder}:/output:z" $BIBImage build --type raw --rootfs ext4 $bibConfigArg --local $LocalImage
$genRaw = Get-ChildItem $OutputFolder -Filter "disk.raw" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genRaw) { Move-Item $genRaw.FullName $RawImg -Force; Write-OK "RAW: $(Get-FileSize $RawImg)" }
else { Write-Warn "RAW failed" }
Clean-BIBTemp

# ── VHDX ─────────────────────────────────────────────────────────────────────
Write-Step "TARGET 2 — VHD → VHDX (Hyper-V Gen2)..."
& podman run --rm -it --privileged -v /var/lib/containers/storage:/var/lib/containers/storage -v "${OutputFolder}:/output:z" $BIBImage build --type vhd --rootfs ext4 $bibConfigArg --local $LocalImage
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
& podman run --rm -it --privileged -v /var/lib/containers/storage:/var/lib/containers/storage -v "${OutputFolder}:/output:z" $BIBImage build --type anaconda-iso --rootfs ext4 $bibConfigArg --local $LocalImage
$genIso = Get-ChildItem $OutputFolder -Filter "*.iso" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($genIso) { Move-Item $genIso.FullName $TargetIso -Force; Write-OK "ISO: $(Get-FileSize $TargetIso)" }
else { Write-Warn "ISO failed" }
Clean-BIBTemp

$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 4: REGISTRY PUSH
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "4" "Registry Push → $GhcrImage"
$ErrorActionPreference = "Continue"
$registryHost = ($GhcrImage -split '/')[0]
if ($RegistryToken) {
    $RegistryToken | podman login $registryHost --username $RegistryUser --password-stdin 2>&1 | Out-Null
}
& podman tag $LocalImage $GhcrImage
$pushOut = & podman push $GhcrImage 2>&1
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
        } catch { Write-Warn "Could not auto-set public visibility" }
    }
} else { Write-Warn "Push failed: $pushOut"; $GhcrOK = $false }
$ErrorActionPreference = "Stop"

# ══════════════════════════════════════════════════════════════════════════════
#  PHASE 5: CLEANUP & REPORT
# ══════════════════════════════════════════════════════════════════════════════
Write-Phase "5" "Cleanup & Report"
$ErrorActionPreference = "Continue"
# Restore user's default podman connection
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
    @(2,"VHDX",$T2,$TargetVhdx,"Hyper-V Gen2 → attach as boot disk"),
    @(3,"WSL2",$T3,$TargetWsl,"wsl --import CloudWS C:\WSL\CloudWS cloudws-wsl.tar"),
    @(4,"ISO",$T4,$TargetIso,"Write to USB with Rufus (ISO mode)"),
    @(5,"Registry",$GhcrOK,$GhcrImage,"sudo bootc switch $GhcrImage")
)) {
    $icon = if($t[2]){"✓"}else{"✗"}; $c = if($t[2]){"Green"}else{"Red"}
    Write-Host "  [$icon] TARGET $($t[0]) — $($t[1])" -ForegroundColor $c
    if($t[2]) { Write-Host "      $($t[3]) ($(Get-FileSize $t[3]))" -ForegroundColor DarkGray; Write-Host "      $($t[4])" -ForegroundColor DarkGray }
    Write-Host ""
}

Write-Host "  Credentials: $U / ****" -ForegroundColor Yellow
Write-Host "  Terminal:    cloudws --help" -ForegroundColor DarkGray
Write-Host "  Cockpit:     https://localhost:9090" -ForegroundColor DarkGray
Write-Host ""
