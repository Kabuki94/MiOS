<#
.SYNOPSIS  Push CloudWS v1.0 modular repo to GitHub
.DESCRIPTION
    Downloads from Claude are FLAT — this script creates the correct folder
    structure (scripts/, scripts/lib/, system_files/), moves files into place,
    extracts system_files.tar, then clones the repo, copies everything, and pushes.

    Usage: Place ALL downloaded files in ONE folder, then run:
           .\push-to-github.ps1
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$RepoUrl  = "https://github.com/Kabuki94/CloudWS-bootc.git"
$Branch   = "main"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v1.0 — Push to GitHub                             ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Source directory (where this script + all downloaded files live) ──
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SourceDir = $ScriptDir
Write-Host "  Source: $SourceDir" -ForegroundColor Gray

if (-not (Test-Path (Join-Path $SourceDir "cloud-ws.ps1"))) {
    Write-Host "  X cloud-ws.ps1 not found in $SourceDir" -ForegroundColor Red
    Write-Host "    Place ALL downloaded CloudWS files in one folder and run from there." -ForegroundColor Yellow
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: ORGANIZE FLAT FILES INTO MODULAR STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  === Organizing files into repo structure ===" -ForegroundColor Yellow

# Create directory structure
$scriptDir_target = Join-Path $SourceDir "scripts"
$libDir_target    = Join-Path $SourceDir "scripts\lib"
$sysDir_target    = Join-Path $SourceDir "system_files"

foreach ($d in @($scriptDir_target, $libDir_target)) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Host "    + Created: $d" -ForegroundColor Green
    }
}

# Move script files into scripts/ (only if they're sitting flat in root)
$scriptFiles = @{
    "build.sh"       = "scripts\build.sh"
    "01-repos.sh"    = "scripts\01-repos.sh"
    "02-kernel.sh"   = "scripts\02-kernel.sh"
    "10-gnome.sh"    = "scripts\10-gnome.sh"
    "11-hardware.sh" = "scripts\11-hardware.sh"
    "12-virt.sh"     = "scripts\12-virt.sh"
    "20-services.sh" = "scripts\20-services.sh"
    "99-overrides.sh"= "scripts\99-overrides.sh"
    "packages.sh"    = "scripts\lib\packages.sh"
}

foreach ($entry in $scriptFiles.GetEnumerator()) {
    $flatSrc = Join-Path $SourceDir $entry.Key
    $dest    = Join-Path $SourceDir $entry.Value
    if ((Test-Path $flatSrc) -and -not (Test-Path $dest)) {
        Move-Item $flatSrc $dest -Force
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    } elseif (Test-Path $dest) {
        Write-Host "    ok $($entry.Value) (already in place)" -ForegroundColor DarkGray
    } elseif (Test-Path $flatSrc) {
        Copy-Item $flatSrc $dest -Force
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    }
}

# Extract system_files.tar if present and system_files/ doesn't exist yet
$tarFile = Join-Path $SourceDir "system_files.tar"
if ((Test-Path $tarFile) -and -not (Test-Path (Join-Path $sysDir_target "etc"))) {
    Write-Host "    Extracting system_files.tar..." -ForegroundColor Cyan
    try {
        # Try tar command (available on Win10+)
        & tar -xf $tarFile -C $SourceDir 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    + Extracted system_files/ ($(( Get-ChildItem $sysDir_target -Recurse -File).Count) files)" -ForegroundColor Green
        } else {
            Write-Host "    ! tar extraction failed — system_files/ may be incomplete" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    ! Could not extract system_files.tar: $_" -ForegroundColor Yellow
    }
} elseif (Test-Path (Join-Path $sysDir_target "etc")) {
    Write-Host "    ok system_files/ (already extracted)" -ForegroundColor DarkGray
}

# Rename dotfiles (Claude outputs as _gitignore etc.)
$dotRenames = @{
    "_gitignore"     = ".gitignore"
    "_gitattributes" = ".gitattributes"
    "_editorconfig"  = ".editorconfig"
}
foreach ($entry in $dotRenames.GetEnumerator()) {
    $src = Join-Path $SourceDir $entry.Key
    $dst = Join-Path $SourceDir $entry.Value
    if ((Test-Path $src) -and -not (Test-Path $dst)) {
        Copy-Item $src $dst -Force
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    }
}

# Show final structure
Write-Host ""
Write-Host "  === Local repo structure ===" -ForegroundColor Cyan
$allFiles = Get-ChildItem $SourceDir -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and $_.Name -ne "system_files.tar"
}
foreach ($f in ($allFiles | Sort-Object FullName)) {
    $rel = $f.FullName.Replace($SourceDir + "\", "")
    Write-Host "    $rel" -ForegroundColor DarkGray
}
Write-Host "    Total: $($allFiles.Count) files" -ForegroundColor White

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2: GITHUB AUTHENTICATION
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  === GitHub Authentication ===" -ForegroundColor Yellow
Write-Host "  PAT needs: repo + write:packages" -ForegroundColor Gray
Write-Host ""
$ghUser  = Read-Host "  GitHub username"
$ghToken = Read-Host "  GitHub PAT" -AsSecureString
$ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))
$AuthUrl = "https://${ghUser}:${ghTokenPlain}@github.com/Kabuki94/CloudWS-bootc.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  X Git not found. Install: winget install Git.Git" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: CLONE REPO & COPY FILES
# ══════════════════════════════════════════════════════════════════════════════
$WorkDir = Join-Path $env:TEMP "cloudws-push-$([guid]::NewGuid().ToString('N').Substring(0,8))"

Write-Host ""
Write-Host "  Cloning $RepoUrl ..." -ForegroundColor Cyan
git clone $AuthUrl $WorkDir 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
if ($LASTEXITCODE -ne 0) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Set-Location $WorkDir
    git init; git remote add origin $AuthUrl; git checkout -b $Branch
} else {
    Set-Location $WorkDir
    git checkout $Branch 2>$null
}
git config user.name $ghUser
git config user.email "${ghUser}@users.noreply.github.com"

# Clean ALL old content (preserve .git)
Write-Host "  Cleaning old repo content..." -ForegroundColor DarkGray
Get-ChildItem $WorkDir -Exclude ".git" | Remove-Item -Recurse -Force

# Copy root files
$rootFiles = @(
    "cloud-ws.ps1", "Containerfile", "Justfile", "PACKAGES.md", "README.md",
    "VERSION", "install.ps1", "install.sh", "preflight.ps1", "push-to-github.ps1",
    ".gitignore", ".gitattributes", ".editorconfig"
)
foreach ($f in $rootFiles) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $f) -Force
        Write-Host "    + $f" -ForegroundColor Green
    }
}

# Copy directory trees
foreach ($d in @("scripts", "system_files", "config")) {
    $src = Join-Path $SourceDir $d
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $d) -Recurse -Force
        $count = (Get-ChildItem (Join-Path $WorkDir $d) -Recurse -File).Count
        Write-Host "    + $d/ ($count files)" -ForegroundColor Green
    }
}

# LICENSE
$licFile = Join-Path $WorkDir "LICENSE"
if (-not (Test-Path $licFile)) {
    $year = (Get-Date).Year
    "MIT License`n`nCopyright (c) $year Kabuki94`n`nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the `"Software`"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:`n`nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.`n`nTHE SOFTWARE IS PROVIDED `"AS IS`", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE." | Out-File $licFile -Encoding ascii
    Write-Host "    + LICENSE (MIT)" -ForegroundColor Green
}

# ── Force LF line endings on all non-PS1 text files ──
Write-Host "  Fixing line endings..." -ForegroundColor DarkGray
Get-ChildItem $WorkDir -Recurse -Include "*.sh","*.md","*.toml","*.conf","*.cfg","*.yaml","*.yml","*.rules","Containerfile","Justfile","VERSION" | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -match "`r`n") {
        $c = $c -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($_.FullName, $c, [System.Text.UTF8Encoding]::new($false))
    }
}
Write-Host "    + LF enforced" -ForegroundColor Green

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4: COMMIT & PUSH
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  === Git Operations ===" -ForegroundColor Yellow
git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host "  No changes — already up to date." -ForegroundColor Green
} else {
    $fileCount = ($status | Measure-Object).Count
    Write-Host "  $fileCount files staged:" -ForegroundColor Gray
    git status --short | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    $defMsg = "CloudWS v1.0 — modular architecture"
    $commitMsg = Read-Host "`n  Commit message (Enter for default)"
    if (-not $commitMsg) { $commitMsg = $defMsg }

    git commit -m $commitMsg
    Write-Host "  Pushing to $Branch ..." -ForegroundColor Cyan
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  === PUSHED SUCCESSFULLY ===" -ForegroundColor Green
        Write-Host "  https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor White
        Write-Host ""
        Write-Host "  === Repo Tree ===" -ForegroundColor Cyan
        git ls-tree -r --name-only HEAD | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else {
        Write-Host "  X Push failed. Check PAT scope." -ForegroundColor Red
    }
}

Set-Location $SourceDir
Write-Host ""
Write-Host "  Working copy: $WorkDir" -ForegroundColor DarkGray
Write-Host ""

$runBuild = Read-Host "  Run full build now? (y/n) [n]"
if ($runBuild -eq 'y') {
    $env:CLOUDWS_GHCR_USER = $ghUser
    $env:CLOUDWS_GHCR_TOKEN = $ghTokenPlain
    & (Join-Path $SourceDir "cloud-ws.ps1")
}
Write-Host ""
