#Requires -Version 7.0
<#
.SYNOPSIS
    Push the CloudWS-bootc GCP integration package to the upstream repo.
.DESCRIPTION
    Clones github.com/Kabuki94/CloudWS-bootc into a temp directory, copies
    every file from push-gcp-integration-files/ into it preserving layout,
    stages, shows a diff, commits with a structured message, and pushes to
    the target branch. Never git-init, never touch VERSION / CHANGELOG.md
    / docs/PACKAGES.md / .ai-context/knowledge-base.md.
.PARAMETER RepoUrl
    HTTPS URL of the target repo.
.PARAMETER Branch
    Target branch (default: main).
.PARAMETER DryRun
    Stop after git diff --cached --stat; do not commit or push.
.PARAMETER NoConfirm
    Skip the interactive push confirmation.
.PARAMETER Token
    Optional GitHub PAT as a SecureString. If provided, injected into the
    clone URL only for this invocation and scrubbed immediately.
.EXAMPLE
    pwsh ./push-gcp-integration.ps1 -DryRun
.EXAMPLE
    pwsh ./push-gcp-integration.ps1 -NoConfirm
#>
[CmdletBinding()]
param(
    [string]       $RepoUrl  = 'https://github.com/Kabuki94/CloudWS-bootc.git',
    [string]       $Branch   = 'main',
    [switch]       $DryRun,
    [switch]       $NoConfirm,
    [SecureString] $Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- output helpers ----------
function Write-Step ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "OK  $m"  -ForegroundColor Green }
function Write-Warn ($m) { Write-Host "WARN $m"  -ForegroundColor Yellow }
function Write-Err  ($m) { Write-Host "ERR  $m"  -ForegroundColor Red }

function Convert-SecureStringToPlain {
    param([SecureString]$s)
    if ($null -eq $s) { return $null }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

# ---------- preflight ----------
$stage = Join-Path $PSScriptRoot 'push-gcp-integration-files'
if (-not (Test-Path $stage)) { Write-Err "staging dir missing: $stage"; exit 1 }

$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git) { Write-Err 'git not found on PATH'; exit 1 }

$protected = @(
    'VERSION',
    'CHANGELOG.md',
    'docs/PACKAGES.md',
    '.ai-context/knowledge-base.md'
)

Write-Step 'scanning staging tree for protected-path collisions'
$collisions = @()
Get-ChildItem -Path $stage -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($stage.Length).TrimStart('\','/') -replace '\\','/'
    if ($protected -contains $rel) { $collisions += $rel }
}
if ($collisions.Count -gt 0) {
    Write-Err 'staging would overwrite protected files:'
    $collisions | ForEach-Object { Write-Err "  $_" }
    exit 2
}
Write-Ok 'no protected-path collisions'

# ---------- clone ----------
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cloudws-push-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
Write-Step "cloning $RepoUrl -> $tmp"

$cloneUrl = $RepoUrl
if ($PSBoundParameters.ContainsKey('Token') -and $Token) {
    $plain = Convert-SecureStringToPlain $Token
    $cloneUrl = $RepoUrl -replace '^https://','https://x-access-token:' + $plain + '@'
    $plain = $null
    [GC]::Collect()
}

& git clone --branch $Branch --single-branch $cloneUrl $tmp 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Err 'git clone failed'; exit 1 }
$cloneUrl = $null
Write-Ok 'clone complete'

# ---------- copy ----------
Write-Step 'copying staging payload into repo'
Get-ChildItem -Path $stage -Recurse -File | ForEach-Object {
    $rel  = $_.FullName.Substring($stage.Length).TrimStart('\','/')
    $dest = Join-Path $tmp $rel
    $ddir = Split-Path -Parent $dest
    if (-not (Test-Path $ddir)) { New-Item -ItemType Directory -Path $ddir -Force | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}
Write-Ok 'copy complete'

# ---------- stage + diff ----------
Push-Location $tmp
try {
    & git add -A 2>&1 | Out-Host
    Write-Step 'staged diff:'
    & git diff --cached --stat 2>&1 | Out-Host

    if ($DryRun) { Write-Warn 'DryRun: stopping before commit'; exit 0 }

    # ---------- commit ----------
    $msg = New-TemporaryFile
    $body = @"
feat(gcp): complete GCP integration package

Adds full reference architecture for CloudWS-bootc on Google Cloud:
- GCE custom OS image pipeline (bib --type gce, UEFI_COMPATIBLE)
- Cloud Workstations custom container image support
- GKE container fleet + optional KubeVirt VM pattern
- KasmVNC + Apache Guacamole browser-native VDI (Quadlets)
- Cockpit systemd sysext for headless loopback access
- Terraform/OpenTofu IaC for the full stack (WIF, IAP, LB)
- GitHub Actions workflows for GAR push + cosign keyless signing

Files: bib-configs/gcp.toml, bib-configs/gcp-workstation.toml,
scripts/14-17, system_files/**, kargs.d/03-cloudws-gcp.toml,
terraform/**, .github/workflows/build-gcp-artifact.yml,
.github/workflows/push-gar.yml, docs/GCP-DEPLOYMENT.md.

Protected files untouched: VERSION, CHANGELOG.md, docs/PACKAGES.md,
.ai-context/knowledge-base.md.

Signed-off-by: push-gcp-integration.ps1
Deliverable-Contract: CLAUDE.md §4
Kargs-Schema: flat top-level kargs=[] only
Bash-Strict: set -euo pipefail; VAR=`$((VAR + 1))
"@
    Set-Content -LiteralPath $msg.FullName -Value $body -NoNewline
    & git commit -F $msg.FullName 2>&1 | Out-Host
    Remove-Item -LiteralPath $msg.FullName -Force
    Write-Ok 'commit created'

    # ---------- push ----------
    if (-not $NoConfirm) {
        $ans = Read-Host "push to origin/$Branch now? [y/N]"
        if ($ans -notmatch '^[Yy]') { Write-Warn 'push skipped by user'; exit 0 }
    }
    Write-Step "pushing to origin/$Branch"
    & git push origin $Branch 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Err 'git push failed'; exit 1 }
    Write-Ok 'push complete'
}
finally {
    Pop-Location
    # ---------- cleanup ----------
    try { Remove-Item -LiteralPath $tmp -Recurse -Force } catch { Write-Verbose $_.Exception.Message }
}
