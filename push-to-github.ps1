<#
.SYNOPSIS  Push CloudWS v1.0 modular repo to GitHub
.DESCRIPTION
    Authenticates with GitHub via PAT, clones/updates the repo,
    copies the FULL modular directory tree (scripts/, system_files/, etc.),
    commits, and pushes. Handles dotfile renames and LF line endings.

    Usage: .\push-to-github.ps1
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$RepoUrl  = "https://github.com/Kabuki94/CloudWS-bootc.git"
$Branch   = "main"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v1.0 — Push to GitHub (Modular Repo)              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SourceDir = $ScriptDir
Write-Host "  Source: $SourceDir" -ForegroundColor Gray

if (-not (Test-Path (Join-Path $SourceDir "cloud-ws.ps1"))) {
    Write-Host "  ✗ cloud-ws.ps1 not found in $SourceDir" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ═══ GitHub Authentication ═══" -ForegroundColor Yellow
Write-Host "  PAT needs: repo + write:packages" -ForegroundColor Gray
Write-Host ""
$ghUser  = Read-Host "  GitHub username"
$ghToken = Read-Host "  GitHub PAT" -AsSecureString
$ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))
$AuthUrl = "https://${ghUser}:${ghTokenPlain}@github.com/Kabuki94/CloudWS-bootc.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ Git not found. Install: winget install Git.Git" -ForegroundColor Red
    exit 1
}

$WorkDir = Join-Path $env:TEMP "cloudws-push-$([guid]::NewGuid().ToString('N').Substring(0,8))"

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

# Clean old files (preserve .git)
Write-Host ""
Write-Host "  ═══ Cleaning old repo contents ═══" -ForegroundColor Yellow
Get-ChildItem $WorkDir -Exclude ".git" | Remove-Item -Recurse -Force
Write-Host "    ✓ Clean slate" -ForegroundColor Green

# ── Copy FULL modular repo tree ──
Write-Host ""
Write-Host "  ═══ Copying Modular Repo ═══" -ForegroundColor Yellow

# Root files with dotfile renames
$rootFiles = @{
    "cloud-ws.ps1"       = "cloud-ws.ps1"
    "Containerfile"      = "Containerfile"
    "Justfile"           = "Justfile"
    "PACKAGES.md"        = "PACKAGES.md"
    "README.md"          = "README.md"
    "VERSION"            = "VERSION"
    "install.ps1"        = "install.ps1"
    "install.sh"         = "install.sh"
    "preflight.ps1"      = "preflight.ps1"
    "push-to-github.ps1" = "push-to-github.ps1"
    "_gitignore"         = ".gitignore"
    "_gitattributes"     = ".gitattributes"
    "_editorconfig"      = ".editorconfig"
}

foreach ($entry in $rootFiles.GetEnumerator()) {
    $src = Join-Path $SourceDir $entry.Key
    # Also check actual dotfile name
    if (-not (Test-Path $src)) {
        $src = Join-Path $SourceDir ("." + $entry.Key.TrimStart("_"))
    }
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $entry.Value) -Force
        Write-Host "    ✓ $($entry.Value)" -ForegroundColor Green
    } else {
        Write-Host "    ○ $($entry.Key) (skipped)" -ForegroundColor DarkGray
    }
}

# Directory trees
foreach ($d in @("scripts", "system_files", "config")) {
    $src = Join-Path $SourceDir $d
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $d) -Recurse -Force
        $count = (Get-ChildItem (Join-Path $WorkDir $d) -Recurse -File).Count
        Write-Host "    ✓ $d/ ($count files)" -ForegroundColor Green
    }
}

# Force LF on all text files that go inside containers
Get-ChildItem $WorkDir -Recurse -Include "*.sh","*.md","*.toml","*.conf","*.cfg","*.yaml","*.yml","*.rules" | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -match "`r`n") {
        $c = $c -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($_.FullName, $c, [System.Text.UTF8Encoding]::new($false))
    }
}
Write-Host "    ✓ LF line endings enforced" -ForegroundColor Green

# LICENSE
$licFile = Join-Path $WorkDir "LICENSE"
if (-not (Test-Path $licFile)) {
    $year = (Get-Date).Year
    "MIT License`n`nCopyright (c) $year Kabuki94`n`nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the `"Software`"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:`n`nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.`n`nTHE SOFTWARE IS PROVIDED `"AS IS`", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE." | Out-File $licFile -Encoding ascii
    Write-Host "    ✓ LICENSE (MIT)" -ForegroundColor Green
}

# ── Git operations ──
Write-Host ""
Write-Host "  ═══ Git Operations ═══" -ForegroundColor Yellow
git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host "  No changes — already up to date." -ForegroundColor Green
} else {
    Write-Host "  Changes:" -ForegroundColor Gray
    git status --short | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    $defMsg = "CloudWS v1.0 — modular architecture"
    $commitMsg = Read-Host "`n  Commit message (default: '$defMsg')"
    if (-not $commitMsg) { $commitMsg = $defMsg }
    git commit -m $commitMsg

    Write-Host "  Pushing to $Branch ..." -ForegroundColor Cyan
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "  ✓ Pushed to GitHub!" -ForegroundColor Green
        Write-Host "    https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor White
        Write-Host ""
        Write-Host "  ═══ Repo Tree ═══" -ForegroundColor Cyan
        git ls-tree -r --name-only HEAD | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else {
        Write-Host "  ✗ Push failed. Check PAT scope." -ForegroundColor Red
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
