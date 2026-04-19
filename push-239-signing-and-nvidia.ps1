#Requires -Version 7.0
<#
.SYNOPSIS
    Push CloudWS-bootc signing + NVIDIA CDI bundle (239).
.DESCRIPTION
    Updates build-sign.yml (key-based + keyless cosign, pinned v2.6.x, SBOM via oras,
    GHCR cleanup), policy.json (adds key-based sigstoreSigned entry, fixes workflow
    filename in keyless entry), and 45-nvidia-cdi-refresh.sh (remove oci-nvidia-hook,
    pin NCT, enable CDI dir).

    PREREQUISITE: Add GitHub secret COSIGN_PRIVATE_KEY + COSIGN_PASSWORD before
    running this push. The key-based sign step is gated on that secret being present.

    Protected files untouched: VERSION, CHANGELOG.md, docs/PACKAGES.md,
    .ai-context/knowledge-base.md.
#>
[CmdletBinding()]
param(
    [string]       $RepoUrl   = 'https://github.com/Kabuki94/CloudWS-bootc.git',
    [string]       $Branch    = 'main',
    [switch]       $DryRun,
    [switch]       $NoConfirm,
    [SecureString] $Token
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step ($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   ($m) { Write-Host "OK  $m"  -ForegroundColor Green }
function Write-Warn ($m) { Write-Host "WARN $m"  -ForegroundColor Yellow }
function Write-Err  ($m) { Write-Host "ERR  $m"  -ForegroundColor Red; exit 1 }

function ConvertTo-Plain ([SecureString]$s) {
    if ($null -eq $s) { return $null }
    $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
    try   { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}

$stage = Join-Path $PSScriptRoot 'push-239-files'
if (-not (Test-Path $stage)) { Write-Err "staging dir missing: $stage" }

$protected = @('VERSION','CHANGELOG.md','docs/PACKAGES.md','.ai-context/knowledge-base.md')
$collisions = Get-ChildItem -Path $stage -Recurse -File |
    ForEach-Object { $_.FullName.Substring($stage.Length).TrimStart('\','/') -replace '\\','/' } |
    Where-Object { $protected -contains $_ }
if ($collisions) { Write-Err "staging collides with protected files: $($collisions -join ', ')" }
Write-Ok 'no protected-path collisions'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cloudws-239-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

Write-Step "cloning $Branch -> $tmp"
$cloneUrl = $RepoUrl
if ($PSBoundParameters.ContainsKey('Token') -and $Token) {
    $plain = ConvertTo-Plain $Token
    $cloneUrl = $RepoUrl -replace '^https://','https://x-access-token:' + $plain + '@'
    $plain = $null; [GC]::Collect()
}
& git clone --branch $Branch --single-branch $cloneUrl $tmp 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Err 'git clone failed' }
$cloneUrl = $null
Write-Ok 'clone complete'

Write-Step 'copying staging payload'
Get-ChildItem -Path $stage -Recurse -File | ForEach-Object {
    $rel  = $_.FullName.Substring($stage.Length).TrimStart('\','/')
    $dest = Join-Path $tmp $rel
    $ddir = Split-Path -Parent $dest
    if (-not (Test-Path $ddir)) { New-Item -ItemType Directory -Path $ddir -Force | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}
Write-Ok 'copy complete'

Push-Location $tmp
try {
    & git add -A 2>&1 | Out-Host
    Write-Step 'staged diff:'
    & git diff --cached --stat 2>&1 | Out-Host
    if ($DryRun) { Write-Warn 'DryRun: stopping before commit'; exit 0 }

    $msg = New-TemporaryFile
    @"
feat(signing): key-based cosign + NVIDIA CDI hardening (239)

build-sign.yml:
  - Add key-based cosign signing via COSIGN_PRIVATE_KEY secret (gated).
  - Pin cosign to v2.6.0 -- do NOT upgrade to v3 until rpm-ostree#5509 resolved
    (v3 new-bundle-format default breaks bootc upgrade verification).
  - Separate sign, sbom, attest, and ghcr-cleanup jobs.
  - SBOM via syft (SPDX+CycloneDX) + oras attach (not cosign attest --
    avoids Rekor size limits that reject large SBOMs).
  - GHCR cleanup job (cron+workflow_dispatch): keep 7 most-recent untagged.

policy.json:
  - Add key-based sigstoreSigned entry (cloudws-cosign.pub) as first entry.
  - Fix keyless entry: workflow filename build-test.yml -> build-sign.yml.

scripts/45-nvidia-cdi-refresh.sh:
  - Remove /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json (dual
    injection with CDI causes device conflicts).
  - Write /etc/nvidia-container-toolkit/cdi-refresh.env with CDI_OUTPUT_PATH.
  - Require NCT >= 1.18 for nvidia-cdi-refresh.{service,path}.
  - Create /etc/cdi/ for persistent CDI spec.

Protected files untouched: VERSION, CHANGELOG.md, docs/PACKAGES.md,
.ai-context/knowledge-base.md.

Deliverable-Contract: CLAUDE.md §4
"@ | Set-Content -LiteralPath $msg.FullName -NoNewline
    & git commit -F $msg.FullName 2>&1 | Out-Host
    Remove-Item -LiteralPath $msg.FullName -Force
    Write-Ok 'commit created'

    if (-not $NoConfirm) {
        $ans = Read-Host "push to origin/$Branch now? [y/N]"
        if ($ans -notmatch '^[Yy]') { Write-Warn 'push skipped by user'; exit 0 }
    }
    Write-Step "pushing to origin/$Branch"
    & git push origin $Branch 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Err 'git push failed' }
    Write-Ok 'push complete'
}
finally {
    Pop-Location
    try { Remove-Item -LiteralPath $tmp -Recurse -Force } catch { Write-Warn "cleanup: $($_.Exception.Message)" }
}
