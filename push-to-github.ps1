<#
.SYNOPSIS  Push CloudWS v2.1+ to GitHub — handles flat downloads + production files
.DESCRIPTION
    Downloads from Claude are FLAT. This script:
    1. Creates scripts/, scripts/lib/, config/, .github/, tests/ folders
    2. MOVES (overwrites) flat .sh files into correct locations
    3. Extracts system_files.tar (if present)
    4. Organizes .github/workflows/, .github/ISSUE_TEMPLATE/, tests/
    5. Places all documentation files at repo root
    6. Cleans up duplicates and garbage
    7. Clones repo, copies tree, commits, pushes
    8. Optionally launches build after push

    NEW in v2.1: Handles CI/CD pipeline, issue templates, PR template,
    smoke tests, and all production documentation files.
#>
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/Kabuki94/CloudWS-bootc.git"
$Branch  = "main"

Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v2.1 — Push to GitHub (Production Files)          ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$SourceDir = $ScriptDir
Write-Host "  Source: $SourceDir" -ForegroundColor Gray

if (-not (Test-Path (Join-Path $SourceDir "cloud-ws.ps1"))) {
    # Try OneDrive repo path
    $OneDrivePath = "$env:USERPROFILE\OneDrive\Documents\GitHub\CloudWS-bootc"
    if (Test-Path (Join-Path $OneDrivePath "cloud-ws.ps1")) {
        $SourceDir = $OneDrivePath
        Write-Host "  Found repo at: $SourceDir" -ForegroundColor Cyan
    } else {
        Write-Host "  X cloud-ws.ps1 not found — run from your CloudWS folder" -ForegroundColor Red
        exit 1
    }
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 1: ORGANIZE FLAT FILES INTO REPO STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "  === Step 1: Organize flat files ===" -ForegroundColor Yellow

# ── Create ALL required directories ──────────────────────────────────────────
$dirsNeeded = @(
    "scripts",
    "scripts\lib",
    "config",
    ".github",
    ".github\workflows",
    ".github\ISSUE_TEMPLATE",
    "tests"
)
foreach ($d in $dirsNeeded) {
    $p = Join-Path $SourceDir $d
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Host "    + Created $d\" -ForegroundColor Green
    }
}

# ── Map flat script files → target paths ─────────────────────────────────────
$scriptMap = @{
    "build.sh"        = "scripts\build.sh"
    "01-repos.sh"     = "scripts\01-repos.sh"
    "02-kernel.sh"    = "scripts\02-kernel.sh"
    "10-gnome.sh"     = "scripts\10-gnome.sh"
    "11-hardware.sh"  = "scripts\11-hardware.sh"
    "12-virt.sh"      = "scripts\12-virt.sh"
    "13-ceph-k3s.sh"  = "scripts\13-ceph-k3s.sh"
    "20-services.sh"  = "scripts\20-services.sh"
    "37-selinux.sh"   = "scripts\37-selinux.sh"
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
        Remove-Item $flatSrc -Force
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    } elseif (Test-Path $dest) {
        Write-Host "    ok $($entry.Value)" -ForegroundColor DarkGray
    }
}

# ── Map flat CI/CD + template files → target paths ───────────────────────────
$ciMap = @{
    "build.yml"               = ".github\workflows\build.yml"
    "bug_report.md"           = ".github\ISSUE_TEMPLATE\bug_report.md"
    "feature_request.md"      = ".github\ISSUE_TEMPLATE\feature_request.md"
    "security_template.md"    = ".github\ISSUE_TEMPLATE\security.md"
    "PULL_REQUEST_TEMPLATE.md" = ".github\PULL_REQUEST_TEMPLATE.md"
    "smoke-test.sh"           = "tests\smoke-test.sh"
}

foreach ($entry in $ciMap.GetEnumerator()) {
    $flatSrc = Join-Path $SourceDir $entry.Key
    $dest = Join-Path $SourceDir $entry.Value
    if (Test-Path $flatSrc) {
        Copy-Item $flatSrc $dest -Force
        Remove-Item $flatSrc -Force
        Write-Host "    -> $($entry.Key) -> $($entry.Value)" -ForegroundColor Green
    } elseif (Test-Path $dest) {
        Write-Host "    ok $($entry.Value)" -ForegroundColor DarkGray
    }
}

# ── Extract system_files.tar (if present) ────────────────────────────────────
$tarFile = Join-Path $SourceDir "system_files.tar"
$sysDir = Join-Path $SourceDir "system_files"
if (Test-Path $tarFile) {
    if (Test-Path $sysDir) { Remove-Item $sysDir -Recurse -Force }
    Write-Host "    Extracting system_files.tar..." -ForegroundColor Cyan
    & tar -xf $tarFile -C $SourceDir 2>&1 | Out-Null
    $count = (Get-ChildItem $sysDir -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "    + system_files/ ($count files)" -ForegroundColor Green
    Remove-Item $tarFile -Force
}

# ── Delete garbage directories ───────────────────────────────────────────────
Get-ChildItem $SourceDir -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^\{' } |
    ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    x Removed garbage dir: $($_.Name)" -ForegroundColor DarkRed
    }

# ── Rename dotfiles ──────────────────────────────────────────────────────────
$dotRenames = @{
    "_gitignore"     = ".gitignore"
    "_gitattributes" = ".gitattributes"
    "_editorconfig"  = ".editorconfig"
}
foreach ($e in $dotRenames.GetEnumerator()) {
    $src = Join-Path $SourceDir $e.Key
    $dst = Join-Path $SourceDir $e.Value
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Remove-Item $src -Force
        Write-Host "    -> $($e.Key) -> $($e.Value)" -ForegroundColor Green
    }
}

# ── Show final local structure ───────────────────────────────────────────────
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
$ghTokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ghToken))
$AuthUrl = "https://${ghUser}:${ghTokenPlain}@github.com/Kabuki94/CloudWS-bootc.git"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  X Git not found" -ForegroundColor Red; exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  STEP 3: CLONE, COPY, PUSH
# ══════════════════════════════════════════════════════════════════════════════
$WorkDir = Join-Path $env:TEMP "cloudws-push-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Write-Host "`n  Cloning repo..." -ForegroundColor Cyan
git clone $AuthUrl $WorkDir 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
if ($LASTEXITCODE -ne 0) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Set-Location $WorkDir
    git init
    git remote add origin $AuthUrl
    git checkout -b $Branch
} else {
    Set-Location $WorkDir
    git checkout $Branch 2>$null
}
git config user.name $ghUser
git config user.email "${ghUser}@users.noreply.github.com"

# Clean ALL old content (except .git)
Get-ChildItem $WorkDir -Exclude ".git" | Remove-Item -Recurse -Force

# ── Copy root files ──────────────────────────────────────────────────────────
$rootFiles = @(
    # Build system
    "cloud-ws.ps1", "Containerfile", "Containerfile.ucore", "Justfile",
    "PACKAGES.md", "VERSION",
    # Installers
    "install.ps1", "install.sh", "preflight.ps1", "push-to-github.ps1",
    # Documentation (NEW v2.1)
    "README.md", "CHANGELOG.md", "CONTRIBUTING.md", "UPGRADE.md",
    "SECURITY.md", "HARDWARE.md", "SELF-BUILD.md", "DIAGNOSTICS.md",
    "BACKUP.md", "LICENSES.md", "PACKAGES-AUDIT.md", "README-ADDENDUM.md",
    # Dependency management (NEW v2.1)
    "image-versions.yml", "renovate.json",
    # Dotfiles
    ".gitignore", ".gitattributes", ".editorconfig",
    # Cosign public key (if exists)
    "cosign.pub"
)

foreach ($f in $rootFiles) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $WorkDir $f) -Force
        Write-Host "    + $f" -ForegroundColor Green
    }
}

# ── Copy directory trees ─────────────────────────────────────────────────────
$dirTrees = @(
    "scripts",
    "system_files",
    "config",
    ".github",
    "tests"
)

foreach ($d in $dirTrees) {
    $src = Join-Path $SourceDir $d
    if (Test-Path $src) {
        $destDir = Join-Path $WorkDir $d
        Copy-Item $src $destDir -Recurse -Force
        $c = (Get-ChildItem $destDir -Recurse -File -ErrorAction SilentlyContinue).Count
        Write-Host "    + $d/ ($c files)" -ForegroundColor Green
    }
}

# ── Generate LICENSE if missing ──────────────────────────────────────────────
$lic = Join-Path $WorkDir "LICENSE"
if (-not (Test-Path $lic)) {
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
"@ | Out-File $lic -Encoding ascii
    Write-Host "    + LICENSE" -ForegroundColor Green
}

# ── Enforce LF line endings ──────────────────────────────────────────────────
$lfExts = @(
    "*.sh", "*.md", "*.toml", "*.conf", "*.cfg", "*.yaml", "*.yml",
    "*.rules", "*.json", "*.xml", "*.service", "*.timer", "*.socket",
    "*.mount", "*.path", "*.te", "*.pp",
    "Containerfile", "Containerfile.*", "Justfile", "VERSION"
)
Get-ChildItem $WorkDir -Recurse -Include $lfExts -ErrorAction SilentlyContinue | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    if ($c -match "`r`n") {
        [System.IO.File]::WriteAllText(
            $_.FullName,
            $c.Replace("`r`n", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
Write-Host "    + LF enforced" -ForegroundColor Green

# ── Verify critical files exist ──────────────────────────────────────────────
Write-Host "`n  === File verification ===" -ForegroundColor Yellow

$criticalFiles = @(
    # Build system
    "Containerfile", "cloud-ws.ps1", "Justfile", "PACKAGES.md", "VERSION",
    # Scripts
    "scripts\build.sh", "scripts\lib\packages.sh",
    "scripts\01-repos.sh", "scripts\02-kernel.sh",
    "scripts\10-gnome.sh", "scripts\11-hardware.sh",
    "scripts\12-virt.sh", "scripts\20-services.sh", "scripts\99-overrides.sh",
    # CI/CD (NEW v2.1)
    ".github\workflows\build.yml",
    ".github\ISSUE_TEMPLATE\bug_report.md",
    ".github\ISSUE_TEMPLATE\feature_request.md",
    ".github\ISSUE_TEMPLATE\security.md",
    ".github\PULL_REQUEST_TEMPLATE.md",
    # Tests (NEW v2.1)
    "tests\smoke-test.sh",
    # Documentation (NEW v2.1)
    "CHANGELOG.md", "CONTRIBUTING.md", "UPGRADE.md", "SECURITY.md",
    "HARDWARE.md", "SELF-BUILD.md", "DIAGNOSTICS.md", "BACKUP.md", "LICENSES.md"
)

$missing = 0
foreach ($f in $criticalFiles) {
    $p = Join-Path $WorkDir $f
    if (Test-Path $p) {
        Write-Host "    ✓ $f" -ForegroundColor Green
    } else {
        Write-Host "    ✗ $f MISSING" -ForegroundColor Red
        $missing = $missing + 1
    }
}

if ($missing -gt 0) {
    Write-Host "`n  WARNING: $missing critical file(s) missing!" -ForegroundColor Yellow
    $proceed = Read-Host "  Continue anyway? (y/n)"
    if ($proceed -ne "y") { Write-Host "  Aborted."; exit 1 }
}

# ── Commit & push ────────────────────────────────────────────────────────────
Write-Host "`n  === Step 3: Push ===" -ForegroundColor Yellow
git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host "  No changes." -ForegroundColor Green
} else {
    $n = ($status | Measure-Object).Count
    Write-Host "  $n files staged" -ForegroundColor Gray
    git status --short | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    $defaultMsg = "CloudWS v2.1 — Production files: CI/CD, signing, SBOM, docs, smoke tests"
    $msg = Read-Host "`n  Commit message (Enter = default)"
    if (-not $msg) { $msg = $defaultMsg }

    git commit -m $msg
    Write-Host "  Pushing..." -ForegroundColor Cyan
    git push -u origin $Branch 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n  ✓ PUSHED!" -ForegroundColor Green
        Write-Host "  https://github.com/Kabuki94/CloudWS-bootc`n" -ForegroundColor White

        # Show final repo tree
        Write-Host "  === Repo contents ===" -ForegroundColor Cyan
        git ls-tree -r --name-only HEAD | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        $total = (git ls-tree -r --name-only HEAD | Measure-Object).Count
        Write-Host "    Total: $total files" -ForegroundColor White

        # Show new files added in this push
        Write-Host "`n  === New production files ===" -ForegroundColor Cyan
        $newFiles = @(
            ".github/workflows/build.yml",
            ".github/ISSUE_TEMPLATE/bug_report.md",
            ".github/ISSUE_TEMPLATE/feature_request.md",
            ".github/ISSUE_TEMPLATE/security.md",
            ".github/PULL_REQUEST_TEMPLATE.md",
            "tests/smoke-test.sh",
            "CHANGELOG.md", "CONTRIBUTING.md", "UPGRADE.md",
            "SECURITY.md", "HARDWARE.md", "SELF-BUILD.md",
            "DIAGNOSTICS.md", "BACKUP.md", "LICENSES.md"
        )
        foreach ($nf in $newFiles) {
            $check = git ls-tree -r --name-only HEAD | Where-Object { $_ -eq $nf }
            if ($check) {
                Write-Host "    ✓ $nf" -ForegroundColor Green
            } else {
                Write-Host "    ✗ $nf (not in repo)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  X Push failed" -ForegroundColor Red
    }
}

# ── Return to source dir BEFORE removing temp ────────────────────────────────
Set-Location $SourceDir

# ── Clean up temp clone ──────────────────────────────────────────────────────
Write-Host "`n  Cleaning temp dir..." -ForegroundColor DarkGray
try {
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
Write-Host "  ═══ Next Steps ═══" -ForegroundColor Yellow
Write-Host "  Push complete. The GitHub Actions CI pipeline will now:" -ForegroundColor White
Write-Host "    1. Build the OCI image" -ForegroundColor DarkGray
Write-Host "    2. Run smoke tests (tests/smoke-test.sh)" -ForegroundColor DarkGray
Write-Host "    3. Rechunk for optimized delta updates" -ForegroundColor DarkGray
Write-Host "    4. Sign with cosign (keyless OIDC)" -ForegroundColor DarkGray
Write-Host "    5. Generate SBOM (SPDX + CycloneDX)" -ForegroundColor DarkGray
Write-Host "    6. Push to ghcr.io/kabuki94/cloudws-bootc:latest" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Or build locally:" -ForegroundColor White
Write-Host ""
Write-Host "  1) Clone fresh from GitHub + build locally (recommended)" -ForegroundColor White
Write-Host "  2) Run smoke tests only" -ForegroundColor White
Write-Host "  3) No thanks, just exit" -ForegroundColor White
Write-Host ""
$buildChoice = Read-Host "  Choice [1-3]"

switch ($buildChoice) {
    "1" {
        Write-Host "`n  Launching installer..." -ForegroundColor Cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $pf = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1" -UseBasicParsing
        Invoke-Expression $pf.Content
    }
    "2" {
        Write-Host "`n  To run smoke tests locally:" -ForegroundColor Cyan
        Write-Host "    podman build --no-cache -t localhost/cloudws:dev ." -ForegroundColor DarkGray
        Write-Host "    bash tests/smoke-test.sh localhost/cloudws:dev" -ForegroundColor DarkGray
    }
    default {
        Write-Host "`n  Done. Build manually with:" -ForegroundColor Gray
        Write-Host "    Set-ExecutionPolicy Bypass -Scope Process -Force" -ForegroundColor DarkGray
        Write-Host "    irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex" -ForegroundColor DarkGray
    }
}
Write-Host ""
