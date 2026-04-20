#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
    CloudWS-bootc v2.3.7 — hard-rules audit fixes
.DESCRIPTION
    Fixes all 6 failing hard-rule sections identified by the build-auditor:
      §3.1  Remove CLOUDWS_RAWHIDE_KERNEL prohibited kernel install block
      §3.2  Fix ((VAR++)) under set -euo pipefail in 7 tools/*.sh files
      §3.2  Fix A&&B||C anti-pattern in scripts/build.sh
      §3.3  Remove nvidia-drm.modeset=1 / fbdev=1 from kargs.d TOML files
      §3.4  Remove categories= key from Gaming + Virtualization dconf folders
      §3.4  Remove non-existent gnome-session-xsession from PACKAGES.md
      §3.5  Remove modeset kargs from all 3 BIB artifact configs
      §3.8  Replace irm|iex advertised pattern with safe temp-file pattern
      §3.9  gnome-session-xsession removal from packages-gnome block
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$REPO_URL  = "https://github.com/Kabuki94/CloudWS-bootc.git"
$BRANCH    = "main"
$VERSION   = "2.3.7"
$WORK_DIR  = Join-Path $env:TEMP "cloudws-push-$VERSION-$(Get-Random)"

Write-Host ""
Write-Host "+============================================================+" -ForegroundColor Cyan
Write-Host "|  CloudWS-bootc push-v$VERSION — hard-rules audit fixes      |" -ForegroundColor Cyan
Write-Host "+============================================================+" -ForegroundColor Cyan
Write-Host ""

# ── Clone ────────────────────────────────────────────────────────────────────
Write-Host "[1/5] Cloning repo to $WORK_DIR ..." -ForegroundColor Yellow
git clone --depth 1 --branch $BRANCH $REPO_URL $WORK_DIR
if ($LASTEXITCODE -ne 0) { throw "git clone failed" }

$REPO = $WORK_DIR

# ── Helper ───────────────────────────────────────────────────────────────────
function Copy-ToRepo($src, $relDest) {
    $dest = Join-Path $REPO $relDest
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    Copy-Item -Path $src -Destination $dest -Force
    Write-Host "  copied: $relDest" -ForegroundColor Green
}

$LOCAL = $PSScriptRoot

# ── [2/5] Copy all edited files ──────────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] Copying edited files ..." -ForegroundColor Yellow

# §3.1 — 01-repos.sh (rawhide kernel block removed)
Copy-ToRepo "$LOCAL/scripts/01-repos.sh" "scripts/01-repos.sh"

# §3.2 — build.sh (A&&B||C fix)
Copy-ToRepo "$LOCAL/scripts/build.sh" "scripts/build.sh"

# §3.2 — tools/*.sh (((VAR++)) fixes)
foreach ($tool in @(
    "tools/vfio-verify.sh",
    "tools/cloud-ws-assess.sh",
    "tools/iommu-visualizer.sh",
    "tools/quick-summary.sh",
    "tools/universal-vfio-configurator.sh",
    "tools/universal-cpu-isolator.sh",
    "tools/vm-cpu-pin-manager.sh"
)) {
    Copy-ToRepo "$LOCAL/$tool" $tool
}

# §3.3 / §3.5 — kargs.d TOML files
Copy-ToRepo "$LOCAL/system_files/usr/lib/bootc/kargs.d/00-cloudws.toml" `
            "system_files/usr/lib/bootc/kargs.d/00-cloudws.toml"
Copy-ToRepo "$LOCAL/system_files/usr/lib/bootc/kargs.d/10-nvidia.toml" `
            "system_files/usr/lib/bootc/kargs.d/10-nvidia.toml"

# §3.5 — BIB artifact configs
Copy-ToRepo "$LOCAL/bib-configs/qcow2.toml" "bib-configs/qcow2.toml"
Copy-ToRepo "$LOCAL/bib-configs/vhdx.toml"  "bib-configs/vhdx.toml"
Copy-ToRepo "$LOCAL/bib-configs/iso.toml"   "bib-configs/iso.toml"

# §3.4 — dconf profile
Copy-ToRepo "$LOCAL/system_files/etc/dconf/db/local.d/01-cloudws" `
            "system_files/etc/dconf/db/local.d/01-cloudws"

# §3.8 — preflight.ps1
Copy-ToRepo "$LOCAL/preflight.ps1" "preflight.ps1"

# ── [3/5] Inline fix: docs/PACKAGES.md (§3.4/§3.9) ─────────────────────────
Write-Host ""
Write-Host "[3/5] Patching docs/PACKAGES.md (remove gnome-session-xsession) ..." -ForegroundColor Yellow

$pkgMd = Join-Path $REPO "docs/PACKAGES.md"
if (-not (Test-Path $pkgMd)) { throw "docs/PACKAGES.md not found in cloned repo" }

$content = Get-Content $pkgMd -Raw
if ($content -notmatch 'gnome-session-xsession') {
    Write-Host "  gnome-session-xsession already absent — skipping" -ForegroundColor Gray
} else {
    # Remove the line (with optional trailing newline)
    $content = $content -replace '(?m)^gnome-session-xsession\r?\n', ''
    Set-Content -Path $pkgMd -Value $content -NoNewline -Encoding UTF8
    Write-Host "  removed gnome-session-xsession" -ForegroundColor Green
}

# Verify it's gone
if ((Get-Content $pkgMd -Raw) -match 'gnome-session-xsession') {
    throw "gnome-session-xsession still present in docs/PACKAGES.md — aborting"
}

# ── [4/5] Bump VERSION ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Bumping VERSION to $VERSION ..." -ForegroundColor Yellow
Set-Content -Path (Join-Path $REPO "VERSION") -Value $VERSION -Encoding UTF8
Write-Host "  VERSION = $VERSION" -ForegroundColor Green

# ── [5/5] Commit + push ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Committing and pushing ..." -ForegroundColor Yellow

Push-Location $REPO
try {
    git add -A
    git status --short

    $msg = @"
v2.3.7: fix all 6 failing hard-rule sections (audit fixes)

§3.1  Remove CLOUDWS_RAWHIDE_KERNEL prohibited kernel install block from
      scripts/01-repos.sh — gated code path still violates the no-in-container-
      kernel-upgrade rule unconditionally.

§3.2  Replace ((VAR++)) under set -euo pipefail with VAR=`$((VAR + 1)) across
      7 tools/*.sh files (vfio-verify, cloud-ws-assess, iommu-visualizer,
      quick-summary, universal-cpu-isolator, universal-vfio-configurator,
      vm-cpu-pin-manager). Fix A&&B||C anti-pattern in scripts/build.sh.

§3.3  Remove nvidia-drm.modeset=1 and nvidia-drm.fbdev=1 from
      system_files/usr/lib/bootc/kargs.d/00-cloudws.toml and 10-nvidia.toml.
      These args belong in modprobe.d (already present), not in kargs shipped
      unconditionally to every image including VMs without a GPU.

§3.4  Remove categories= key from Gaming and Virtualization dconf app-folder
      definitions in system_files/etc/dconf/db/local.d/01-cloudws.
      Remove non-existent gnome-session-xsession from docs/PACKAGES.md.

§3.5  Remove nvidia-drm.modeset=1 and nvidia-drm.fbdev=1 from the kernel
      append line in bib-configs/qcow2.toml, vhdx.toml, and iso.toml.
      Shipping these in a Hyper-V VHDX or QEMU qcow2 causes GDM boot failure.
      The modprobe.d blacklist + 34-gpu-detect.sh runtime gating is correct
      and untouched.

§3.8  Replace irm|iex advertised invocation with safe temp-file pattern
      in preflight.ps1 synopsis comment and user-facing help text.
"@

    $msgFile = Join-Path $WORK_DIR "commit-msg.txt"
    Set-Content -Path $msgFile -Value $msg -Encoding UTF8
    git commit -F $msgFile
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }

    git push origin $BRANCH
    if ($LASTEXITCODE -ne 0) { throw "git push failed" }

    Write-Host ""
    Write-Host "+============================================================+" -ForegroundColor Green
    Write-Host "|  v$VERSION pushed successfully                               |" -ForegroundColor Green
    Write-Host "+============================================================+" -ForegroundColor Green
} finally {
    Pop-Location
    Write-Host ""
    Write-Host "Cleaning up $WORK_DIR ..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $WORK_DIR -ErrorAction SilentlyContinue
}
