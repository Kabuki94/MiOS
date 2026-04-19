#Requires -Version 7.0
<#
.SYNOPSIS
    Push CloudWS-bootc dev-ergonomics bundle (238):
    kargs.d schema validator + kargs-lint CI workflow + research doc update.
.DESCRIPTION
    Clones github.com/Kabuki94/CloudWS-bootc, copies push-238-files/ atomically,
    shows a diff, commits, and pushes. Never git-init, never touches protected files.
.PARAMETER Branch
    Target branch (default: main).
.PARAMETER DryRun
    Stop after git diff --cached --stat; do not commit or push.
.PARAMETER NoConfirm
    Skip the interactive push confirmation prompt.
.PARAMETER Token
    Optional GitHub PAT as SecureString.
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

$stage = Join-Path $PSScriptRoot 'push-238-files'
if (-not (Test-Path $stage)) { Write-Err "staging dir missing: $stage" }

$protected = @('VERSION','CHANGELOG.md','docs/PACKAGES.md','.ai-context/knowledge-base.md')
$collisions = Get-ChildItem -Path $stage -Recurse -File |
    ForEach-Object { $_.FullName.Substring($stage.Length).TrimStart('\','/') -replace '\\','/' } |
    Where-Object { $protected -contains $_ }
if ($collisions) { Write-Err "staging collides with protected files: $($collisions -join ', ')" }
Write-Ok 'no protected-path collisions'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cloudws-238-" + [Guid]::NewGuid())
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
feat(ci): add kargs.d schema validator + kargs-lint workflow

scripts/validate-kargs.py: ~200-line Python 3.11+ stdlib-only validator.
  Walks kargs.d/ and system_files/usr/lib/bootc/kargs.d/*.toml. Raw-text
  scan for [section] headers, tomllib parse, structural checks (allowed
  keys: kargs + match-architectures only). Modes: human, --github, --json.
  Exit 0 pass / 1 fail / 2 usage.

.github/workflows/kargs-lint.yml: new dedicated workflow (additive, does
  not touch pr-lint.yml). Runs validate-kargs.py --github on PR + push to
  main. Python 3.12, timeout 3 min, scoped to kargs.d/** changes.

docs/knowledge/research/17-upstream-bootc-ecosystem-2025-2026.md: updated
  with full upstream ecosystem research (April 2026 snapshot).

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
