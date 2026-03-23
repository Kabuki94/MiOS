#Requires -RunAsAdministrator
<#
.SYNOPSIS  CloudWS Bootstrap — Downloads and runs the full build script
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
$Repo = "https://github.com/Kabuki94/CloudWS-bootc"
$RawBase = "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main"
$Dir = Join-Path $PWD "CloudWS-bootc"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v3.3 — Cloud Workstation OS Builder (Windows)      ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Run preflight check first (recommended)" -ForegroundColor White
Write-Host "  2) Clone repo + run full build (cloud-ws.ps1)" -ForegroundColor White
Write-Host "  3) Download build script only" -ForegroundColor White
Write-Host ""
$choice = Read-Host "  Choice [1-3]"

switch ($choice) {
    "1" {
        Write-Host "`n  Running preflight check..." -ForegroundColor Cyan
        $pf = Invoke-WebRequest -Uri "$RawBase/preflight.ps1" -UseBasicParsing
        Invoke-Expression $pf.Content
        Write-Host "`n  Preflight complete. Run this script again and choose option 2." -ForegroundColor Green
    }
    "2" {
        Write-Host "`n  Cloning $Repo ..." -ForegroundColor Cyan
        if (Test-Path $Dir) { Set-Location $Dir; git pull }
        else { git clone $Repo $Dir; Set-Location $Dir }
        Write-Host "  ✓ Repository cloned to $Dir" -ForegroundColor Green
        Write-Host "  Launching build script..." -ForegroundColor Cyan
        & "$Dir\cloud-ws.ps1"
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
