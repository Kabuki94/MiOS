<#
.SYNOPSIS
    CloudWS v1.3 — Push all build files to GitHub repository

.DESCRIPTION
    Downloads flat files from the output directory and organizes them into
    the correct repo structure, then pushes to GitHub.

    CHANGELOG v1.3:
      - Added bootc kargs.d drop-in (system_files/usr/lib/bootc/kargs.d/)
      - Added composefs prepare-root.conf (system_files/usr/lib/ostree/)
      - Added sysctl hardening (system_files/usr/lib/sysctl.d/)
      - Updated VERSION to 1.3.0
      - Added nvidia-open.conf to modprobe.d

    CRITICAL: Flat files ALWAYS overwrite existing repo copies to prevent
    stale cached versions from persisting.
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ══════════════════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════
$RepoRoot = Get-Location
$Version = Get-Content "VERSION" -ErrorAction SilentlyContinue
if (-not $Version) { $Version = "1.3.0" } else { $Version = $Version.Trim() }

$GitUser = $env:CLOUDWS_GHCR_USER
$GitToken = $env:CLOUDWS_GHCR_TOKEN
$RemoteUrl = "https://github.com/Kabuki94/CloudWS-bootc.git"

Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CloudWS v$Version — Push to GitHub" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: CREATE DIRECTORY STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [1] Ensuring directory structure..." -ForegroundColor Yellow
foreach ($dir in @(
    "scripts", "scripts/lib", "config", "system_files",
    "system_files/usr/lib/bootc/kargs.d",
    "system_files/usr/lib/ostree",
    "system_files/usr/lib/sysctl.d",
    "system_files/usr/lib/tmpfiles.d"
)) {
    $fullPath = Join-Path $RepoRoot $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "      Created: $dir" -ForegroundColor DarkCyan
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2: ORGANIZE FILES INTO CORRECT LOCATIONS
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [2] Organizing files..." -ForegroundColor Yellow

# --- Root-level files ---
$rootFiles = @(
    "Containerfile",
    "PACKAGES.md",
    "VERSION",
    "Justfile",
    "iso.toml",
    "cloud-ws.ps1",
    "install.ps1",
    "install.sh",
    "preflight.ps1",
    "README.md"
)
foreach ($f in $rootFiles) {
    if (Test-Path (Join-Path $RepoRoot $f)) {
        Write-Host "      ✓ $f" -ForegroundColor Green
    }
}

# --- Move flat script files to scripts/ ---
$scriptFiles = @(
    "build.sh",
    "01-repos.sh",
    "02-kernel.sh",
    "10-gnome.sh",
    "11-hardware.sh",
    "12-virt.sh",
    "20-services.sh",
    "99-overrides.sh",
    "cloudws-toggle-headless",
    "cloudws-test"
)
foreach ($f in $scriptFiles) {
    $flatPath = Join-Path $RepoRoot $f
    $destPath = Join-Path $RepoRoot "scripts/$f"
    if ((Test-Path $flatPath) -and -not ($flatPath -eq $destPath)) {
        Move-Item $flatPath $destPath -Force
        Write-Host "      ✓ $f → scripts/$f" -ForegroundColor Green
    } elseif (Test-Path $destPath) {
        Write-Host "      ✓ scripts/$f" -ForegroundColor Green
    }
}

# --- Move lib files ---
$libPath = Join-Path $RepoRoot "packages.sh"
if (Test-Path $libPath) {
    Move-Item $libPath (Join-Path $RepoRoot "scripts/lib/packages.sh") -Force
    Write-Host "      ✓ packages.sh → scripts/lib/packages.sh" -ForegroundColor Green
}

# --- Config files ---
foreach ($f in @("bib.json", "bib.toml")) {
    $flatPath = Join-Path $RepoRoot $f
    $destPath = Join-Path $RepoRoot "config/$f"
    if ((Test-Path $flatPath) -and -not ($flatPath -eq $destPath)) {
        Move-Item $flatPath $destPath -Force
        Write-Host "      ✓ $f → config/$f" -ForegroundColor Green
    }
}

# --- Extract system_files.tar if present ---
$sfTar = Join-Path $RepoRoot "system_files.tar"
if (Test-Path $sfTar) {
    Write-Host "      Extracting system_files.tar..." -ForegroundColor DarkCyan
    $sfDir = Join-Path $RepoRoot "system_files"
    tar xf $sfTar -C $sfDir 2>$null
    Remove-Item $sfTar -Force
    Write-Host "      ✓ system_files extracted" -ForegroundColor Green
}

# --- Rename dotfiles ---
$dotfiles = @{
    "_gitattributes" = ".gitattributes"
    "_gitignore" = ".gitignore"
    "_editorconfig" = ".editorconfig"
}
foreach ($src in $dotfiles.Keys) {
    $srcPath = Join-Path $RepoRoot $src
    $dstPath = Join-Path $RepoRoot $dotfiles[$src]
    if (Test-Path $srcPath) {
        Move-Item $srcPath $dstPath -Force
        Write-Host "      ✓ $src → $($dotfiles[$src])" -ForegroundColor Green
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: VERIFY v1.3 NEW FILES
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [3] Verifying v1.3 new files..." -ForegroundColor Yellow

$v13NewFiles = @(
    "system_files/usr/lib/bootc/kargs.d/00-cloudws.toml",
    "system_files/usr/lib/ostree/prepare-root.conf",
    "system_files/usr/lib/sysctl.d/99-cloudws-hardening.conf"
)
foreach ($f in $v13NewFiles) {
    $fp = Join-Path $RepoRoot $f
    if (Test-Path $fp) {
        Write-Host "      ✓ $f (NEW v1.3)" -ForegroundColor Cyan
    } else {
        Write-Host "      ✗ $f MISSING" -ForegroundColor Red
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4: GIT OPERATIONS
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [4] Git operations..." -ForegroundColor Yellow

# Set remote with token auth
if ($GitUser -and $GitToken) {
    $authUrl = "https://${GitUser}:${GitToken}@github.com/Kabuki94/CloudWS-bootc.git"
    git remote set-url origin $authUrl 2>$null
    Write-Host "      ✓ Remote authenticated" -ForegroundColor Green
}

# Stage all changes
git add -A
$status = git status --porcelain
if ($status) {
    $changeCount = ($status -split "`n").Count
    Write-Host "      $changeCount files changed" -ForegroundColor DarkCyan

    git commit -m "v${Version}: Intelligence report update — bootc v1.15, SecureBlue hardening, RTX 50 VFIO, composefs, kargs.d, dnf5 cache"
    Write-Host "      ✓ Committed" -ForegroundColor Green

    git push origin main
    Write-Host "      ✓ Pushed to GitHub" -ForegroundColor Green
} else {
    Write-Host "      No changes to push" -ForegroundColor DarkGray
}

# ══════════════════════════════════════════════════════════════════════════════
#  DONE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CloudWS v$Version — Push complete" -ForegroundColor Green
Write-Host "  Repository: https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor DarkCyan
Write-Host "══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
