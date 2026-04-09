<#
.SYNOPSIS  Push CloudWS v1.0 to GitHub — handles flat downloads
.DESCRIPTION
    Downloads from Claude are FLAT. This script:
    1. Creates scripts/, scripts/lib/ folders
    2. MOVES (overwrites) flat .sh files into correct locations
    3. Extracts system_files.tar
    4. Cleans up duplicates (_gitignore, system_files.tar, flat .sh copies)
    5. Clones repo, copies tree, commits, pushes
    6. Optionally launches build after push
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/Kabuki94/CloudWS-bootc.git"
$Branch  = "main"

Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v1.0 — Push to GitHub                             ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SourceDir = $ScriptDir
Write-Host "  Source: $SourceDir" -ForegroundColor Gray

if (-not (Test-Path (Join-Path $SourceDir "cloud-ws.ps1"))) {
    Write-Host "  X cloud-ws.ps1 not found — run from your CloudWS folder" -ForegroundColor Red; exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: ORGANIZE FLAT FILES INTO REPO STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  === Step 1: Organize flat files ===" -ForegroundColor Yellow

# Create directories
$dirsNeeded = @("scripts", "scripts\lib", "config")
foreach ($d in $dirsNeeded) {
    $p = Join-Path $SourceDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null; Write-Host "    + Created $d\" -ForegroundColor Green }
}

# Map flat filenames → target paths (ALWAYS overwrite target with flat version)
$scriptMap = @{
    "build.sh"        = "scripts\build.sh"
    "01-repos.sh"     = "scripts\01-repos.sh"
    "02-kernel.sh"    = "scripts\02-kernel.sh"
    "10-gnome.sh"     = "scripts\10-gnome.sh"
    "11-hardware.sh"  = "scripts\11-hardware.sh"
    "12-virt.sh"      = "scripts\12-virt.sh"
    "20-services.sh"  = "scripts\20-services.sh"
    "99-overrides.sh" = "scripts\99-overrides.sh"
    "packages.sh"     = "scripts\lib\packages.sh"
    "bib.toml"        = "config\bib.toml"
    "bib.json"        = "config\bib.json"
}

foreach ($entry in $scriptMap.GetEnumerator()) {
    $flatSrc = Join-Path $SourceDir $entry.Key
    $dest = Join-Path $SourceDir $entry.Value
    if (Test-Path $flatSrc) {
        Copy-Item $flatSrc $dest -Force
        Remove-Item $flatSrc -Force  # Remove flat copy after placing
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    } elseif (Test-Path $dest) {
        Write-Host "    ok $($entry.Value)" -ForegroundColor DarkGray
    }
}

# Extract system_files.tar
$tarFile = Join-Path $SourceDir "system_files.tar"
$sysDir = Join-Path $SourceDir "system_files"
if (Test-Path $tarFile) {
    # Remove any existing system_files to get clean extraction
    if (Test-Path $sysDir) { Remove-Item $sysDir -Recurse -Force }
    Write-Host "    Extracting system_files.tar..." -ForegroundColor Cyan
    & tar -xf $tarFile -C $SourceDir 2>&1 | Out-Null
    $count = (Get-ChildItem $sysDir -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "    + system_files/ ($count files)" -ForegroundColor Green
    Remove-Item $tarFile -Force  # Clean up tar after extraction
}

# Delete garbage directory with literal curly braces (from earlier bug)
Get-ChildItem $SourceDir -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\{' } | ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    x Removed garbage dir: $($_.Name)" -ForegroundColor DarkRed
}

# Rename dotfiles
$dotRenames = @{ "_gitignore"=".gitignore"; "_gitattributes"=".gitattributes"; "_editorconfig"=".editorconfig" }
foreach ($e in $dotRenames.GetEnumerator()) {
    $src = Join-Path $SourceDir $e.Key; $dst = Join-Path $SourceDir $e.Value
    if (Test-Path $src) { Copy-Item $src $dst -Force; Remove-Item $src -Force; Write-Host "    -> $($e.Key) -> $($e.Value)" -ForegroundColor Green }
}

# Show final local structure
Write-Host "`n  === Local structure ===" -ForegroundColor Cyan
$localFiles = Get-ChildItem $SourceDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Extension -ne '.tar' }
$localFiles | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($SourceDir.Length + 1)
    Write-Host "    $rel" -ForegroundColor DarkGray
}
Write-Host "    Total: $($localFiles.Count) files" -ForegroundColor White

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 2: AUTHENTICATE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "`n  === Step 2: GitHub Auth ===" -ForegroundColor Yellow
$ghUser = Read-Host "  GitHub username"
$ghToken = Read-Host "  GitHub PAT" -AsSecureString
$ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))
$AuthUrl = "https://${ghUser}:${ghTokenPlain}@github.com/Kabuki94/CloudWS-bootc.git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "  X Git not found" -ForegroundColor Red; exit 1 }

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: CLONE, COPY, PUSH
# ══════════════════════════════════════════════════════════════════════════════
$WorkDir = Join-Path $env:TEMP "cloudws-push-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Write-Host "`n  Cloning repo..." -ForegroundColor Cyan
git clone $AuthUrl $WorkDir 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
if ($LASTEXITCODE -ne 0) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Set-Location $WorkDir; git init; git remote add origin $AuthUrl; git checkout -b $Branch
} else { Set-Location $WorkDir; git checkout $Branch 2>$null }
git config user.name $ghUser
git config user.email "${ghUser}@users.noreply.github.com"

# Clean ALL old content
Get-ChildItem $WorkDir -Exclude ".git" | Remove-Item -Recurse -Force

# Copy root files
foreach ($f in @("cloud-ws.ps1","Containerfile","Justfile","PACKAGES.md","README.md","VERSION","install.ps1","install.sh","preflight.ps1","push-to-github.ps1",".gitignore",".gitattributes",".editorconfig")) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $WorkDir $f) -Force; Write-Host "    + $f" -ForegroundColor Green }
}

# Copy directory trees
foreach ($d in @("scripts","system_files","config")) {
    $src = Join-Path $SourceDir $d
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $d) -Recurse -Force
        $c = (Get-ChildItem (Join-Path $WorkDir $d) -Recurse -File).Count
        Write-Host "    + $d/ ($c files)" -ForegroundColor Green
    }
}

# LICENSE
$lic = Join-Path $WorkDir "LICENSE"
if (-not (Test-Path $lic)) {
    "MIT License`n`nCopyright (c) $((Get-Date).Year) Kabuki94`n`nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the `"Software`"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:`n`nThe above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.`n`nTHE SOFTWARE IS PROVIDED `"AS IS`", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT." | Out-File $lic -Encoding ascii
    Write-Host "    + LICENSE" -ForegroundColor Green
}

# LF line endings
Get-ChildItem $WorkDir -Recurse -Include "*.sh","*.md","*.toml","*.conf","*.cfg","*.yaml","*.yml","*.rules","Containerfile","Justfile","VERSION" | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -match "`r`n") { [System.IO.File]::WriteAllText($_.FullName, $c.Replace("`r`n","`n"), [System.Text.UTF8Encoding]::new($false)) }
}
Write-Host "    + LF enforced" -ForegroundColor Green

# Commit & push
Write-Host "`n  === Step 3: Push ===" -ForegroundColor Yellow
git add -A
$status = git status --porcelain
if (-not $status) { Write-Host "  No changes." -ForegroundColor Green }
else {
    $n = ($status | Measure-Object).Count
    Write-Host "  $n files staged" -ForegroundColor Gray
    git status --short | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    $msg = Read-Host "`n  Commit message (Enter = default)"
    if (-not $msg) { $msg = "CloudWS v1.0" }
    git commit -m $msg
    Write-Host "  Pushing..." -ForegroundColor Cyan
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  PUSHED!" -ForegroundColor Green
        Write-Host "  https://github.com/Kabuki94/CloudWS-bootc`n" -ForegroundColor White
        git ls-tree -r --name-only HEAD | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else { Write-Host "  X Push failed" -ForegroundColor Red }
}

# Return to source dir BEFORE removing temp
Set-Location $SourceDir

# Clean up temp clone (no read-only folders left behind)
Write-Host "`n  Cleaning temp dir..." -ForegroundColor DarkGray
try {
    # Git marks .git objects read-only — force-remove them
    if (Test-Path $WorkDir) {
        Get-ChildItem $WorkDir -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Attributes -band [IO.FileAttributes]::ReadOnly } |
            ForEach-Object { $_.Attributes = $_.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly) }
        Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    ✓ Temp cleaned: $WorkDir" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "    ⚠ Could not fully remove temp dir: $WorkDir" -ForegroundColor DarkYellow
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 4: OFFER BUILD
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ═══ Build? ═══" -ForegroundColor Yellow
Write-Host "  Push complete. Would you like to clone fresh and run the build now?" -ForegroundColor White
Write-Host ""
Write-Host "  1) Clone fresh from GitHub + build (recommended)" -ForegroundColor White
Write-Host "  2) No thanks, just exit" -ForegroundColor White
Write-Host ""
$buildChoice = Read-Host "  Choice [1-2]"

if ($buildChoice -eq "1") {
    Write-Host "`n  Launching installer..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    $pf = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1" -UseBasicParsing
    Invoke-Expression $pf.Content
} else {
    Write-Host "`n  Done. Build manually with:" -ForegroundColor Gray
    Write-Host "    Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex" -ForegroundColor DarkGray
}
Write-Host ""
