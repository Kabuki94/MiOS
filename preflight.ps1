if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-Host '  Run as Administrator!' -ForegroundColor Red; return }
<#
.SYNOPSIS  CloudWS Preflight — Check and install prerequisites
.DESCRIPTION
    Usage: irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/preflight.ps1 | iex
#>
$ErrorActionPreference = "Continue"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CloudWS Preflight — Prerequisites Check                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$pass = 0; $fail = 0; $fixed = 0

function Check($name, $test, $fix) {
    Write-Host "  [$name] " -NoNewline
    if (& $test) { Write-Host "✓" -ForegroundColor Green; $script:pass++ }
    else {
        Write-Host "✗ Missing" -ForegroundColor Red
        $script:fail++
        if ($fix) {
            $doFix = Read-Host "    Install $name? (y/n)"
            if ($doFix -eq 'y') { & $fix; $script:fixed++ }
        }
    }
}

# Windows Edition
Write-Host "═══ System ═══" -ForegroundColor Yellow
Check "Windows 10/11 Pro+" { (Get-CimInstance Win32_OperatingSystem).Caption -match "Pro|Enterprise|Education" } $null

# WSL2
Write-Host "`n═══ WSL2 ═══" -ForegroundColor Yellow
Check "WSL2 Feature" { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 'Enabled' } {
    Write-Host "    Enabling WSL..." -ForegroundColor Cyan
    wsl --install --no-distribution
    Write-Host "    ⚠ Reboot required after WSL install" -ForegroundColor Yellow
}
Check "Virtual Machine Platform" { (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq 'Enabled' } {
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
}

# Hyper-V
Write-Host "`n═══ Hyper-V (optional) ═══" -ForegroundColor Yellow
Check "Hyper-V" { (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State -eq 'Enabled' } {
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    Write-Host "    ⚠ Reboot required" -ForegroundColor Yellow
}

# Software
Write-Host "`n═══ Software ═══" -ForegroundColor Yellow
Check "Git" { Get-Command git -ErrorAction SilentlyContinue } {
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
}
Check "Podman" { Get-Command podman -ErrorAction SilentlyContinue } {
    winget install --id RedHat.Podman --accept-source-agreements --accept-package-agreements
}
Check "Podman Desktop" { Get-Command "podman-desktop" -ErrorAction SilentlyContinue -or (Test-Path "$env:LOCALAPPDATA\Programs\Podman Desktop") } {
    winget install --id RedHat.Podman-Desktop --accept-source-agreements --accept-package-agreements
}

# Summary
Write-Host "`n═══ Results ═══" -ForegroundColor Cyan
Write-Host "  Passed: $pass  Failed: $fail  Fixed: $fixed" -ForegroundColor White
if ($fail -eq 0 -or $fail -eq $fixed) {
    Write-Host "  ✓ Ready to build CloudWS!" -ForegroundColor Green
    Write-Host "    Run: irm https://raw.githubusercontent.com/Kabuki94/CloudWS-bootc/main/install.ps1 | iex" -ForegroundColor Gray
} else {
    Write-Host "  ⚠ Some prerequisites missing. Fix them and re-run." -ForegroundColor Yellow
}
Write-Host ""
