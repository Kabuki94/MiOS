# MiOS Public Bootstrap for Windows
# Repository: Kabuki94/mios-bootstrap
# Usage: irm https://raw.githubusercontent.com/Kabuki94/mios-bootstrap/main/bootstrap.ps1 | iex

$ErrorActionPreference = "Stop"
$PrivateRepo = "https://raw.githubusercontent.com/Kabuki94/mios/main"

Write-Host ""
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host "  |  🌐 MiOS Private Bootstrap (Windows)                         |" -ForegroundColor Cyan
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host ""

# Use Read-Host -MaskInput (PS 7.1+, handles paste correctly)
Write-Host "  Enter GitHub Personal Access Token (requires 'repo' scope):" -ForegroundColor White
$token = Read-Host -MaskInput

if (-not $token) {
    Write-Host "  [!] Token required to access the private MiOS repository." -ForegroundColor Red
    exit 1
}

# Set environment variable for inheritance by the private installer
$env:GHCR_TOKEN = $token

$headers = @{ Authorization = "token $token" }
$target = "$env:TEMP\mios-install-stage2.ps1"

Write-Host "  [+] Fetching private installer..." -ForegroundColor Gray
try {
    # We use -UseBasicParsing to avoid IE engine dependencies
    Invoke-WebRequest -Uri "$PrivateRepo/install.ps1" -Headers $headers -OutFile $target -UseBasicParsing
    Write-Host "  [OK] Handoff to private installer.`n" -ForegroundColor Green
    & $target
} catch {
    Write-Host "  [!] Failed to fetch private installer. Check your token and repository permissions." -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Gray
    exit 1
}
