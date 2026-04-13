<#
.SYNOPSIS  Fix Bibata cursor download in 10-gnome.sh — replaces hardcoded version with dynamic GitHub API lookup
.DESCRIPTION
    The hardcoded BIBATA_VER="2.0.8" returns 404 (that version was never released).
    This script patches scripts/10-gnome.sh to use the GitHub API for the latest tag,
    with v2.0.7 as fallback.

    Run from your CloudWS-bootc repo root:
      .\fix-bibata.ps1
#>
$ErrorActionPreference = "Stop"

$Target = "scripts/10-gnome.sh"
if (-not (Test-Path $Target)) {
    $Target = "scripts\10-gnome.sh"
}
if (-not (Test-Path $Target)) {
    Write-Host "  X Cannot find scripts/10-gnome.sh — run from repo root" -ForegroundColor Red
    exit 1
}

Write-Host "`n  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  Fix Bibata Cursor — Patch 10-gnome.sh                     ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Read the file as a single string (preserve LF)
$raw = [System.IO.File]::ReadAllText((Resolve-Path $Target).Path)

# ── Verify the broken section exists ─────────────────────────────────────────
if ($raw -notmatch 'BIBATA_VER="2\.0\.8"') {
    if ($raw -match 'api\.github\.com/repos/ful1e5/Bibata_Cursor') {
        Write-Host "  Already patched (dynamic API lookup found). Nothing to do." -ForegroundColor Green
        exit 0
    }
    Write-Host "  WARNING: Could not find BIBATA_VER=`"2.0.8`" in $Target" -ForegroundColor Yellow
    Write-Host "  Searching for any BIBATA_VER line..." -ForegroundColor Yellow
    $match = ($raw | Select-String 'BIBATA_VER=' | Out-String).Trim()
    if ($match) {
        Write-Host "  Found: $match" -ForegroundColor DarkGray
    } else {
        Write-Host "  No BIBATA_VER found at all. Manual fix required." -ForegroundColor Red
        exit 1
    }
}

# ── Define the OLD block (what to find) ──────────────────────────────────────
# This matches the exact pattern in the current 10-gnome.sh
$oldBlock = @'
echo "[10-gnome] Installing Bibata-Modern-Classic cursor v2.0.8..."
BIBATA_VER="2.0.8"
mkdir -p /usr/share/icons
curl -sL "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz" \
    -o /tmp/bibata.tar.xz 2>/dev/null || true
if [ -f /tmp/bibata.tar.xz ]; then
    tar -xf /tmp/bibata.tar.xz -C /usr/share/icons/ 2>/dev/null || true
    rm -f /tmp/bibata.tar.xz
fi
'@

# ── Also handle the retry-loop variant (v1.3 style with FATAL block) ────────
$oldBlockRetry = @'
echo "[10-gnome] Installing Bibata-Modern-Classic cursor v2.0.8 (MANDATORY)..."
'@

# ── Define the NEW block (replacement) ───────────────────────────────────────
$newBlock = @'
echo "[10-gnome] Installing Bibata-Modern-Classic cursor (MANDATORY)..."
BIBATA_VER=""
BIBATA_FALLBACK="2.0.7"

# Try GitHub API for latest release tag (strips leading 'v')
BIBATA_VER=$(curl -sL "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" \
    | grep -m1 '"tag_name"' | sed 's/.*"v\?\([^"]*\)".*/\1/' 2>/dev/null || true)

# Fallback if API fails (rate limit, network issue)
if [ -z "$BIBATA_VER" ]; then
    BIBATA_VER="$BIBATA_FALLBACK"
    echo "[10-gnome]   GitHub API unavailable — using fallback v${BIBATA_VER}"
else
    echo "[10-gnome]   Latest release: v${BIBATA_VER}"
fi

BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/download/v${BIBATA_VER}/Bibata-Modern-Classic.tar.xz"

mkdir -p /usr/share/icons
BIBATA_OK=0
'@

# ── Apply the patch ──────────────────────────────────────────────────────────
$patched = $false

# Strategy 1: Replace the simple (non-retry) block
if ($raw.Contains($oldBlock)) {
    Write-Host "  Found simple Bibata block — replacing..." -ForegroundColor Cyan
    $raw = $raw.Replace($oldBlock, $newBlock)
    $patched = $true
}

# Strategy 2: Replace just the version line + echo (retry variant)
if (-not $patched -and $raw.Contains($oldBlockRetry)) {
    Write-Host "  Found retry-loop Bibata block — replacing header + version..." -ForegroundColor Cyan
    $raw = $raw.Replace($oldBlockRetry, $newBlock)
    # Remove the old BIBATA_VER="2.0.8" line if it still exists after header swap
    $raw = $raw -replace '(?m)^BIBATA_VER="2\.0\.8"\s*\n', ''
    $patched = $true
}

# Strategy 3: Surgical — just swap the version string everywhere
if (-not $patched) {
    Write-Host "  Using surgical replacement — swapping all v2.0.8 references..." -ForegroundColor Cyan

    # Replace the hardcoded version assignment
    $raw = $raw -replace 'BIBATA_VER="2\.0\.8"', @'
BIBATA_VER=""
BIBATA_FALLBACK="2.0.7"

# Try GitHub API for latest release tag (strips leading 'v')
BIBATA_VER=$(curl -sL "https://api.github.com/repos/ful1e5/Bibata_Cursor/releases/latest" \
    | grep -m1 '"tag_name"' | sed 's/.*"v\?\([^"]*\)".*/\1/' 2>/dev/null || true)

# Fallback if API fails (rate limit, network issue)
if [ -z "$BIBATA_VER" ]; then
    BIBATA_VER="$BIBATA_FALLBACK"
    echo "[10-gnome]   GitHub API unavailable — using fallback v${BIBATA_VER}"
else
    echo "[10-gnome]   Latest release: v${BIBATA_VER}"
fi
'@

    # Fix the echo line that mentions v2.0.8
    $raw = $raw -replace 'echo "\[10-gnome\] Installing Bibata-Modern-Classic cursor v2\.0\.8[^"]*"', `
        'echo "[10-gnome] Installing Bibata-Modern-Classic cursor (MANDATORY)..."'

    # Fix the FATAL message URL if it has hardcoded version
    $raw = $raw -replace 'URL: https://github\.com/ful1e5/Bibata_Cursor/releases/download/v2\.0\.8/Bibata-Modern-Classic\.tar\.xz', `
        'URL: ${BIBATA_URL}'

    # Fix the changelog comment at the top of the file
    $raw = $raw -replace 'Bibata cursor v2\.0\.8', 'Bibata cursor (dynamic version via GitHub API)'

    $patched = $true
}

# ── Write the patched file ───────────────────────────────────────────────────
if ($patched) {
    # Ensure LF line endings
    $raw = $raw.Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        (Resolve-Path $Target).Path,
        $raw,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "`n  ✓ Patched $Target" -ForegroundColor Green
    Write-Host "    - Removed hardcoded BIBATA_VER=`"2.0.8`"" -ForegroundColor DarkGray
    Write-Host "    - Added GitHub API lookup with v2.0.7 fallback" -ForegroundColor DarkGray
    Write-Host "    - Fixed echo/FATAL messages" -ForegroundColor DarkGray
    Write-Host "    - LF line endings enforced" -ForegroundColor DarkGray
} else {
    Write-Host "`n  X Could not patch — manual edit required" -ForegroundColor Red
    exit 1
}

# ── Verify the patch ────────────────────────────────────────────────────────
$verify = [System.IO.File]::ReadAllText((Resolve-Path $Target).Path)
if ($verify -match 'api\.github\.com/repos/ful1e5/Bibata_Cursor') {
    Write-Host "`n  ✓ Verification: GitHub API lookup present" -ForegroundColor Green
} else {
    Write-Host "`n  X Verification FAILED — API lookup not found in patched file" -ForegroundColor Red
    exit 1
}

if ($verify -match 'BIBATA_VER="2\.0\.8"') {
    Write-Host "  X Verification FAILED — hardcoded v2.0.8 still present!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  ✓ Verification: No hardcoded v2.0.8 remains" -ForegroundColor Green
}

if ($verify -match 'BIBATA_FALLBACK="2\.0\.7"') {
    Write-Host "  ✓ Verification: Fallback set to v2.0.7" -ForegroundColor Green
}

Write-Host "`n  Done. Re-run your build." -ForegroundColor White
Write-Host ""
