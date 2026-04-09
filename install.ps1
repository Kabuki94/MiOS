<#
.SYNOPSIS
    CloudWS v1.4 — One-line installer (Windows)
.DESCRIPTION
    Downloads and launches the CloudWS build system.
    NEVER prompts for or displays tokens — that happens inside cloud-ws.ps1.
#>

$ErrorActionPreference = "Stop"
$RepoUrl  = "https://github.com/Kabuki94/CloudWS-bootc"
$RawBase  = "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v1.4 — Cloud Workstation OS Builder (Windows)     ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Run preflight check first (recommended)" -ForegroundColor White
Write-Host "  2) Clone repo + launch build (cloud-ws.ps1)" -ForegroundColor White
Write-Host "  3) Download build script only" -ForegroundColor White
Write-Host ""
Write-Host "  Choice [1-3]: " -NoNewline -ForegroundColor Yellow
$choice = Read-Host

switch ($choice) {
    "1" {
        Write-Host "`n  Running preflight checks..." -ForegroundColor Cyan
        try {
            Invoke-Expression (Invoke-WebRequest -Uri "$RawBase/preflight.ps1" -UseBasicParsing).Content
        } catch {
            Write-Host "  ✗ Preflight download failed: $_" -ForegroundColor Red
        }
    }
    "2" {
        $cloneDest = Join-Path $PWD "CloudWS-bootc"
        if (Test-Path $cloneDest) {
            Write-Host "`n  Updating existing repo at $cloneDest ..." -ForegroundColor Cyan
            Push-Location $cloneDest
            & git pull --rebase 2>&1 | Out-Null
            Pop-Location
            Write-Host "  ✓ Repository updated" -ForegroundColor Green
        } else {
            Write-Host "`n  Cloning $RepoUrl ..." -ForegroundColor Cyan
            & git clone $RepoUrl $cloneDest
            if ($LASTEXITCODE -ne 0) { Write-Host "  ✗ Clone failed" -ForegroundColor Red; exit 1 }
            Write-Host "  ✓ Repository cloned to $cloneDest" -ForegroundColor Green
        }
        Write-Host "  Launching build script..." -ForegroundColor Cyan
        Push-Location $cloneDest
        & .\cloud-ws.ps1
        Pop-Location
    }
    "3" {
        Write-Host "`n  Downloading cloud-ws.ps1 ..." -ForegroundColor Cyan
        $script = Join-Path $PWD "cloud-ws.ps1"
        Invoke-WebRequest -Uri "$RawBase/cloud-ws.ps1" -OutFile $script
        Write-Host "  ✓ Saved to $script" -ForegroundColor Green
        Write-Host "  Run it:  .\cloud-ws.ps1" -ForegroundColor White
    }
    default { Write-Host "  Invalid choice." -ForegroundColor Red }
}
