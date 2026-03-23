#Requires -RunAsAdministrator
<#
.SYNOPSIS  CloudWS Bootstrap — Downloads and runs the full build script
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex
    Or:    Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
$Repo = "https://github.com/Kabuki94/CloudWS-bootc"
$RawBase = "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main"
$Dir = Join-Path $PWD "CloudWS-bootc"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS — Cloud Workstation OS Builder (Windows)           ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Clone repo + run full build (cloud-ws.ps1)" -ForegroundColor White
Write-Host "  2) Download build script only" -ForegroundColor White
Write-Host "  3) Pull pre-built image from GHCR + deploy" -ForegroundColor White
Write-Host ""
$choice = Read-Host "  Choice [1-3]"

switch ($choice) {
    "1" {
        Write-Host "`n  Cloning $Repo ..." -ForegroundColor Cyan
        if (Test-Path $Dir) {
            Set-Location $Dir
            git pull
        } else {
            git clone $Repo $Dir
            Set-Location $Dir
        }
        Write-Host "  ✓ Repository cloned to $Dir" -ForegroundColor Green
        Write-Host "  Launching build script..." -ForegroundColor Cyan
        & "$Dir\cloud-ws.ps1"
    }
    "2" {
        Write-Host "`n  Downloading cloud-ws.ps1 ..." -ForegroundColor Cyan
        $script = Join-Path $PWD "cloud-ws.ps1"
        Invoke-WebRequest -Uri "$RawBase/cloud-ws.ps1" -OutFile $script
        Write-Host "  ✓ Saved to $script" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Run it:  .\cloud-ws.ps1" -ForegroundColor White
    }
    "3" {
        Write-Host "`n  Pulling from GHCR..." -ForegroundColor Cyan
        podman pull ghcr.io/kabuki94/cloudws-bootc:latest
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Image pulled: ghcr.io/kabuki94/cloudws-bootc:latest" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Deploy options:" -ForegroundColor Yellow
            Write-Host "    WSL2:    podman export → wsl --import" -ForegroundColor Gray
            Write-Host "    Hyper-V: bootc-image-builder → VHDX" -ForegroundColor Gray
            Write-Host "    USB:     bootc-image-builder → ISO" -ForegroundColor Gray
            Write-Host ""
            $runBuild = Read-Host "  Run full build pipeline now? (y/n)"
            if ($runBuild -eq 'y') {
                Write-Host "  Downloading cloud-ws.ps1 ..." -ForegroundColor Cyan
                $script = Join-Path $PWD "cloud-ws.ps1"
                Invoke-WebRequest -Uri "$RawBase/cloud-ws.ps1" -OutFile $script
                & $script
            }
        } else {
            Write-Host "  ✗ Pull failed. Is Podman running?" -ForegroundColor Red
        }
    }
    default {
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
}
