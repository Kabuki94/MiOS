$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  Run as Administrator!" -ForegroundColor Red
    return
}
$RepoUrl = "https://github.com/Kabuki94/MiOS"

# --- Credential Handling ---
if (-not $env:GHCR_TOKEN) {
    $token = Read-Host "  GitHub Container Registry Token (optional, press enter to skip)"
    if ($token) { $env:GHCR_TOKEN = $token }
}

function Invoke-SecureWebRequest {
    param([string]$Uri, [string]$OutFile)
    $params = @{ Uri = $Uri; UseBasicParsing = $true }
    if ($env:GHCR_TOKEN -and ($Uri -match "github\.com" -or $Uri -match "ghcr\.io")) {
        $params.Headers = @{ Authorization = "Bearer $($env:GHCR_TOKEN)" }
    }
    if ($OutFile) { $params.OutFile = $OutFile }
    return Invoke-WebRequest @params
}

# Read version from repo VERSION file, fallback to hardcoded
$Ver = "v2.1.0"
try { $Ver = "v" + (Invoke-SecureWebRequest -Uri "$RepoUrl/raw/main/VERSION").Content.Trim() } catch { Write-Verbose "Failed to fetch version: $_" }

Write-Host ""
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host ("  |  MiOS {0} -- MiOS Builder (Windows) " -f $Ver).PadRight(65) + "|" -ForegroundColor Cyan
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) Run preflight check first (recommended)" -ForegroundColor White
Write-Host "  2) Clone repo + launch build (cloud-ws.ps1)" -ForegroundColor White
Write-Host "  3) Download build script only" -ForegroundColor White
Write-Host ""
$choice = Read-Host "  Choice [1-3]"
switch ($choice) {
    "1" {
        try {
            $tmp = "$env:TEMP\mios-preflight-$(Get-Random).ps1"
            Invoke-SecureWebRequest -Uri "$RepoUrl/raw/main/preflight.ps1" -OutFile $tmp
            & $tmp
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "  Preflight failed: $_" -ForegroundColor Red
        }
    }
    "2" {
        $dest = Join-Path $PWD "MiOS"
        if (Test-Path $dest) {
            Write-Host "  [OK] Repository found at $dest -- updating..." -ForegroundColor Cyan
            Push-Location $dest
            git pull --rebase 2>&1 | Out-Null
            Pop-Location
            Write-Host "  [OK] Updated $dest" -ForegroundColor Green
        }
        else {
            Write-Host "  Cloning $RepoUrl ..." -ForegroundColor Cyan
            git clone $RepoUrl $dest
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [X] Clone failed" -ForegroundColor Red
                return
            }
            Write-Host "  [OK] Repository cloned to $dest" -ForegroundColor Green
        }
        Write-Host "  Launching build script..." -ForegroundColor Cyan
        Push-Location $dest
        & .\cloud-ws.ps1
        Pop-Location
    }
    "3" {
        Invoke-SecureWebRequest -Uri "$RepoUrl/raw/main/cloud-ws.ps1" -OutFile "cloud-ws.ps1"
        Write-Host "  [OK] Saved. Run: .\cloud-ws.ps1" -ForegroundColor Green
    }
    default {
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
}