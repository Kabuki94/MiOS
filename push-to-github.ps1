#Requires -RunAsAdministrator
<#
.SYNOPSIS  Push CloudWS v3.13 files to GitHub
.DESCRIPTION
    Authenticates with GitHub via PAT, clones/updates the repo,
    copies all current files, commits, and pushes.
    
    Usage: .\push-to-github.ps1
#>
$ErrorActionPreference = "Stop"

$RepoUrl  = "https://github.com/Kabuki94/CloudWS-bootc.git"
$RepoName = "CloudWS-bootc"
$Branch   = "main"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS — Push to GitHub                                   ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Locate source files ──
# Script assumes all repo files are in the same directory as this script,
# OR you can set $SourceDir to point elsewhere.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SourceDir = $ScriptDir
Write-Host "  Source directory: $SourceDir" -ForegroundColor Gray

# Verify at least cloud-ws.ps1 exists
if (-not (Test-Path (Join-Path $SourceDir "cloud-ws.ps1"))) {
    Write-Host "  ✗ cloud-ws.ps1 not found in $SourceDir" -ForegroundColor Red
    Write-Host "    Place this script in the same folder as your CloudWS files." -ForegroundColor Yellow
    exit 1
}

# ── GitHub Authentication ──
Write-Host ""
Write-Host "  ═══ GitHub Authentication ═══" -ForegroundColor Yellow
Write-Host "  PAT needs scopes: repo (full control)" -ForegroundColor Gray
Write-Host "  Create at: https://github.com/settings/tokens/new" -ForegroundColor Cyan
Write-Host ""
$ghUser  = Read-Host "  GitHub username"
$ghToken = Read-Host "  GitHub PAT (repo scope)" -AsSecureString
$ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))

# Build authenticated URL
$AuthUrl = "https://${ghUser}:${ghTokenPlain}@github.com/Kabuki94/CloudWS-bootc.git"

# ── Check for git ──
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ Git not found. Install with: winget install Git.Git" -ForegroundColor Red
    exit 1
}

# ── Clone or update repo ──
$WorkDir = Join-Path $env:TEMP "cloudws-push-$([guid]::NewGuid().ToString('N').Substring(0,8))"

Write-Host ""
Write-Host "  Cloning $RepoUrl ..." -ForegroundColor Cyan
git clone $AuthUrl $WorkDir 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
if ($LASTEXITCODE -ne 0) {
    # Repo might be empty/new — init instead
    Write-Host "  Clone failed — initializing new repo..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Set-Location $WorkDir
    git init
    git remote add origin $AuthUrl
    git checkout -b $Branch
} else {
    Set-Location $WorkDir
    git checkout $Branch 2>$null
}

# ── Configure git identity ──
git config user.name $ghUser
git config user.email "${ghUser}@users.noreply.github.com"

# ── Copy all repo files ──
Write-Host ""
Write-Host "  ═══ Copying Files ═══" -ForegroundColor Yellow

# Define the complete file manifest
$files = @(
    "cloud-ws.ps1",
    "install.ps1",
    "install.sh",
    "preflight.ps1",
    "push-to-github.ps1",
    "PACKAGES.md",
    "README.md",
    "_gitignore"
)

# Also pick up Containerfile and build_files if they exist
$extraFiles = @("Containerfile", "LICENSE")
$extraDirs  = @("build_files")

foreach ($f in $files) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        $destName = if ($f -eq "_gitignore") { ".gitignore" } else { $f }
        Copy-Item $src (Join-Path $WorkDir $destName) -Force
        Write-Host "    ✓ $destName" -ForegroundColor Green
    } else {
        Write-Host "    ○ $f (not found, skipped)" -ForegroundColor DarkGray
    }
}

foreach ($f in $extraFiles) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $f) -Force
        Write-Host "    ✓ $f" -ForegroundColor Green
    }
}

foreach ($d in $extraDirs) {
    $src = Join-Path $SourceDir $d
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $d) -Recurse -Force
        Write-Host "    ✓ $d/" -ForegroundColor Green
    }
}

# ── Ensure .gitignore is named correctly ──
$giSrc = Join-Path $WorkDir "_gitignore"
$giDst = Join-Path $WorkDir ".gitignore"
if ((Test-Path $giSrc) -and -not (Test-Path $giDst)) {
    Move-Item $giSrc $giDst -Force
    Write-Host "    ✓ Renamed _gitignore → .gitignore" -ForegroundColor Green
}

# ── Ensure install.sh has LF line endings ──
$installSh = Join-Path $WorkDir "install.sh"
if (Test-Path $installSh) {
    $content = [System.IO.File]::ReadAllText($installSh)
    $content = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($installSh, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "    ✓ install.sh → LF line endings" -ForegroundColor Green
}

# ── Create LICENSE if missing ──
$licFile = Join-Path $WorkDir "LICENSE"
if (-not (Test-Path $licFile)) {
    $year = (Get-Date).Year
    @"
MIT License

Copyright (c) $year Kabuki94

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ | Out-File $licFile -Encoding ascii
    Write-Host "    ✓ LICENSE (MIT, created)" -ForegroundColor Green
}

# ── Stage, commit, push ──
Write-Host ""
Write-Host "  ═══ Git Operations ═══" -ForegroundColor Yellow

git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host "  No changes to commit — repo is already up to date." -ForegroundColor Green
} else {
    Write-Host "  Changes staged:" -ForegroundColor Gray
    git status --short | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    
    $commitMsg = Read-Host "`n  Commit message (default: 'CloudWS v3.13 — full rebuild')"
    if (-not $commitMsg) { $commitMsg = "CloudWS v3.13 — full rebuild" }
    
    git commit -m $commitMsg
    
    Write-Host ""
    Write-Host "  Pushing to $Branch ..." -ForegroundColor Cyan
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✓ Successfully pushed to GitHub!" -ForegroundColor Green
        Write-Host "    https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor White
    } else {
        Write-Host "  ✗ Push failed." -ForegroundColor Red
        Write-Host "    Check that your PAT has 'repo' scope and the repository exists." -ForegroundColor Yellow
        Write-Host "    Create the repo at: https://github.com/new" -ForegroundColor Cyan
    }
}

# ── Cleanup ──
Set-Location $SourceDir
# Don't remove WorkDir in case user wants to inspect
Write-Host ""
Write-Host "  Working copy at: $WorkDir" -ForegroundColor DarkGray
Write-Host ""

# ── Next steps ──
Write-Host "  ═══ Next Steps ═══" -ForegroundColor Cyan
Write-Host "    1. Verify: https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor White
Write-Host "    2. Make GHCR package public:" -ForegroundColor White
Write-Host "       https://github.com/Kabuki94?tab=packages" -ForegroundColor Gray
Write-Host ""

$runBuild = Read-Host "  Run full build now? (y/n) [n]"
if ($runBuild -eq 'y') {
    $buildScript = Join-Path $SourceDir "cloud-ws.ps1"
    if (Test-Path $buildScript) {
        Write-Host "`n  Launching cloud-ws.ps1 (GitHub credentials will be reused)..." -ForegroundColor Cyan
        # Pass GHCR credentials via environment so cloud-ws.ps1 can skip the GHCR prompt
        $env:CLOUDWS_GHCR_USER = $ghUser
        $env:CLOUDWS_GHCR_TOKEN = $ghTokenPlain
        & $buildScript
    } else {
        Write-Host "  ✗ cloud-ws.ps1 not found in $SourceDir" -ForegroundColor Red
    }
}
Write-Host ""
