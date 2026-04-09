#Requires -RunAsAdministrator
<#
.SYNOPSIS  CloudWS Bootstrap — Downloads and runs the full build script
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex
#>
$ErrorActionPreference = "Stop"
$Repo = "https://github.com/Kabuki94/CloudWS-bootc"
$RawBase = "https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main"
$ParentDir = $PWD.Path
$Dir = Join-Path $ParentDir "CloudWS-bootc"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  CloudWS v1.0 — Cloud Workstation OS Builder (Windows)     ║" -ForegroundColor Cyan
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

        # CRITICAL: Always ensure CWD is the parent BEFORE touching $Dir.
        # If CWD is inside $Dir, Remove-Item fails with "being used by another process".
        Set-Location $ParentDir

        if (Test-Path $Dir) {
            # Check if it's a valid git repo with the right content
            $isGitRepo = Test-Path (Join-Path $Dir ".git")
            if ($isGitRepo) {
                Set-Location $Dir
                $pullResult = git pull 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  Git pull failed — re-cloning..." -ForegroundColor Yellow
                    Set-Location $ParentDir
                    Remove-Item $Dir -Recurse -Force
                    git clone $Repo $Dir
                }
            } else {
                Write-Host "  Existing directory is not a git repo — re-cloning..." -ForegroundColor Yellow
                # CWD is already $ParentDir — safe to remove
                Remove-Item $Dir -Recurse -Force
                git clone $Repo $Dir
            }
        } else {
            git clone $Repo $Dir
        }

        Set-Location $Dir
        Write-Host "  ✓ Repository cloned to $Dir" -ForegroundColor Green

        if (Test-Path ".\cloud-ws.ps1") {
            Write-Host "  Launching build script..." -ForegroundColor Cyan
            & ".\cloud-ws.ps1"
        } else {
            Write-Host "  ✗ cloud-ws.ps1 not found in $Dir" -ForegroundColor Red
            Write-Host "    The repo may be empty or push is pending." -ForegroundColor Yellow
            Write-Host "    Check: https://github.com/Kabuki94/CloudWS-bootc" -ForegroundColor Yellow
        }
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
