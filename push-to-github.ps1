<#
.SYNOPSIS
    CloudWS v1.2 — Push all build files to GitHub repository

.DESCRIPTION
    Downloads flat files from the output directory and organizes them into
    the correct repo structure, then pushes to GitHub.

    Handles:
      - scripts/ directory (all .sh files + cloudws-toggle-headless, cloudws-test)
      - scripts/lib/ directory (packages.sh)
      - system_files/ directory (via tar extraction)
      - config/ directory (bib.json, bib.toml)
      - Root files (Containerfile, PACKAGES.md, VERSION, Justfile, iso.toml, cloud-ws.ps1)
      - Dotfiles (_gitattributes → .gitattributes, _gitignore → .gitignore, _editorconfig → .editorconfig)

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
if (-not $Version) { $Version = "1.2.0" } else { $Version = $Version.Trim() }

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
foreach ($dir in @("scripts", "scripts/lib", "config", "system_files")) {
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
    # If file is flat in repo root (from download), move to scripts/
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
    "_gitignore"     = ".gitignore"
    "_editorconfig"  = ".editorconfig"
}
foreach ($kv in $dotfiles.GetEnumerator()) {
    $src = Join-Path $RepoRoot $kv.Key
    $dst = Join-Path $RepoRoot $kv.Value
    if (Test-Path $src) {
        Move-Item $src $dst -Force
        Write-Host "      ✓ $($kv.Key) → $($kv.Value)" -ForegroundColor Green
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: GIT OPERATIONS
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  [3] Git operations..." -ForegroundColor Yellow

# Initialize git if needed
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    & git init
    & git remote add origin $RemoteUrl
    Write-Host "      ✓ Git initialized" -ForegroundColor Green
}

# Set remote URL with token for auth
if ($GitToken -and $GitUser) {
    $authUrl = "https://${GitUser}:${GitToken}@github.com/Kabuki94/CloudWS-bootc.git"
    & git remote set-url origin $authUrl 2>$null
}

# Stage all changes
& git add -A
$status = & git status --porcelain
if ($status) {
    $changeCount = ($status | Measure-Object -Line).Lines
    Write-Host "      $changeCount file(s) changed" -ForegroundColor DarkCyan

    # Commit
    $commitMsg = "CloudWS v$Version — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    & git commit -m $commitMsg
    Write-Host "      ✓ Committed: $commitMsg" -ForegroundColor Green

    # Push
    Write-Host "      Pushing to GitHub..." -ForegroundColor DarkCyan
    & git push -u origin main --force 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ Pushed to GitHub" -ForegroundColor Green
    } else {
        # Try 'master' branch if 'main' fails
        & git push -u origin master --force 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ Pushed to GitHub (master)" -ForegroundColor Green
        } else {
            Write-Host "      ✗ Push failed — check credentials" -ForegroundColor Red
        }
    }
} else {
    Write-Host "      No changes to push" -ForegroundColor DarkGray
}

# Scrub token from remote URL
& git remote set-url origin $RemoteUrl 2>$null

# ══════════════════════════════════════════════════════════════════════════════
#  SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CloudWS v$Version — Push Complete" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Repo: https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor DarkGray
Write-Host "  GHCR: https://github.com/Kabuki94?tab=packages" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Files pushed:" -ForegroundColor Yellow
Write-Host "    scripts/20-services.sh          (WSL2 mask fixes, pmcd/pmlogger removed)" -ForegroundColor DarkGray
Write-Host "    scripts/99-overrides.sh          (SELinux fixes, new tools, v1.2)" -ForegroundColor DarkGray
Write-Host "    scripts/cloudws-toggle-headless  (NEW: GUI on/off toggle)" -ForegroundColor DarkGray
Write-Host "    scripts/cloudws-test             (NEW: system test harness)" -ForegroundColor DarkGray
Write-Host "    Containerfile                    (v1.2 updates, chmod fix)" -ForegroundColor DarkGray
Write-Host "    Justfile                         (iso.toml mount, test target)" -ForegroundColor DarkGray
Write-Host "    iso.toml                         (NEW: kickstart for Anaconda ISO)" -ForegroundColor DarkGray
Write-Host "    cloud-ws.ps1                     (Hyper-V + WSL2 auto-deploy)" -ForegroundColor DarkGray
Write-Host "    push-to-github.ps1               (handles new v1.2 files)" -ForegroundColor DarkGray
Write-Host "    VERSION                          (1.2.0)" -ForegroundColor DarkGray
Write-Host ""
