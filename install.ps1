$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  Run as Administrator!" -ForegroundColor Red
    return
}
$RepoUrl = "https://github.com/Kabuki94/CloudWS-bootc"

# Read version from repo VERSION file, fallback to hardcoded
$Ver = "v0.1.3"
try { $Ver = "v" + (Invoke-WebRequest -Uri "$RepoUrl/raw/main/VERSION" -UseBasicParsing).Content.Trim() } catch { Write-Verbose "Failed to fetch version: $_" }

Write-Host ""
Write-Host "  +==============================================================+" -ForegroundColor Cyan
Write-Host ("  |  CloudWS {0} -- Cloud Workstation OS Builder (Windows) " -f $Ver).PadRight(65) + "|" -ForegroundColor Cyan
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
            $tmp = New-TemporaryFile
            Invoke-WebRequest -Uri "$RepoUrl/raw/main/preflight.ps1" -OutFile $tmp.FullName -UseBasicParsing
            & $tmp.FullName
            Remove-Item $tmp.FullName -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "  Preflight failed: $_" -ForegroundColor Red
        }
    }
    "2" {
        $dest = Join-Path $PWD "CloudWS-bootc"
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
        Invoke-WebRequest -Uri "$RepoUrl/raw/main/cloud-ws.ps1" -OutFile "cloud-ws.ps1"
        Write-Host "  [OK] Saved. Run: .\cloud-ws.ps1" -ForegroundColor Green
    }
    default {
        Write-Host "  Invalid choice." -ForegroundColor Red
    }
}