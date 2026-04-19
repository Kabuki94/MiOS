#Requires -Version 7.0
<#
.SYNOPSIS
    Push CloudWS-bootc verification + MOK + FreeIPA bundle (240).
.DESCRIPTION
    Delivers:
      - verify-root.sh: 3-tier composefs verification (existence + fsverity + policy.json SHA-256)
      - cloudws-verify-root.service: hardened systemd unit (Before=greenboot-healthcheck)
      - greenboot required.d check: wires verify-root.sh into automatic rollback
      - docs/COMPOSEFS-VERIFICATION.md: explains chain, Tier B no-op caveat, escape hatch
      - enroll-mok.sh: replacement (mokutil-based, idempotent, variant-aware, PCR7 warning)
      - generate-mok-key.sh: one-shot MOK key generator (2048-bit, shim-compatible)
      - mok-enroll-status: machine-readable probe
      - docs/SECUREBOOT.md: full chain diagram, MOK workflow, PCR7 re-seal, troubleshooting
      - scripts/50-freeipa-client.sh: layer FreeIPA packages, assert SSSD caps, enable service
      - system_files/etc/sssd/conf.d/10-cloudws.conf: nss/pam defaults
      - system_files/usr/lib/systemd/system/cloudws-ipa-enroll.service: opt-in oneshot
      - system_files/usr/libexec/cloudws/ipa-enroll: enrollment helper script
      - system_files/etc/cloudws/ipa.conf.example: commented config template
      - system_files/usr/lib/tmpfiles.d/cloudws-freeipa.conf: expanded dir skeleton

    This push is additive (defense-in-depth). No existing functionality removed.
    FreeIPA is opt-in via ConditionPathExists=/etc/cloudws/ipa.conf.

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

$stage = Join-Path $PSScriptRoot 'push-240-files'
if (-not (Test-Path $stage)) { Write-Err "staging dir missing: $stage" }

$protected = @('VERSION','CHANGELOG.md','docs/PACKAGES.md','.ai-context/knowledge-base.md')
$collisions = Get-ChildItem -Path $stage -Recurse -File |
    ForEach-Object { $_.FullName.Substring($stage.Length).TrimStart('\','/') -replace '\\','/' } |
    Where-Object { $protected -contains $_ }
if ($collisions) { Write-Err "staging collides with protected files: $($collisions -join ', ')" }
Write-Ok 'no protected-path collisions'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cloudws-240-" + [Guid]::NewGuid())
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
feat(security): composefs verification + MOK polish + FreeIPA stack (240)

verify-root.sh (3-tier replacement):
  Tier A: ~22 critical path existence checks (bootc, podman, systemd, gdm,
    cockpit.socket, cloudws helpers, SELinux, os-release, kernel modules).
  Tier B: fsverity measure against /usr/lib/cloudws/verify-root.digests
    (advisory; no-op under default unsigned Fedora composefs -- documented).
  Tier C: policy.json SHA-256 vs /usr/lib/cloudws/policy.json.sha256
    (hard check -- baseline lives under /usr, composefs-covered).

cloudws-verify-root.service: Before=greenboot-healthcheck.service,
  full systemd hardening (ProtectSystem=strict, MemoryDenyWriteExecute,
  PrivateNetwork, NoNewPrivileges, SystemCallFilter=@system-service).

greenboot integration: new required.d/10-cloudws-composefs.sh wires
  verify-root.sh into greenboot retry/rollback chain.

enroll-mok.sh (replacement): mokutil-based (sbctl removed -- wrong tool
  for Fedora GRUB2+shim). Variant-aware (CloudWS-1 key vs CloudWS-2 ublue
  key). Idempotent (exits 0 if enrolled/pending). --root-pw (no shipped
  secret). Rollback on failure. TPM2 PCR7 re-seal warning in final banner.

generate-mok-key.sh: one-shot, 2048-bit RSA (not 4096 -- shim compat),
  10-year validity, codeSigning + MS Kernel Module Code Signing EKU.
  Refuses to overwrite existing key.

mok-enroll-status: machine-readable probe.
  Emits: enrolled | pending | not-enrolled | no-secureboot | conflict.

FreeIPA/SSSD (opt-in, ConditionPathExists=/etc/cloudws/ipa.conf):
  50-freeipa-client.sh: layers packages, asserts SSSD file capabilities
    (bz 2320133), disables services at build, enables enrollment oneshot.
  cloudws-ipa-enroll.service: After=network-online, 300s timeout.
  ipa-enroll: parses conf, runs ipa-client-install, writes domain drop-in
    (selinux_provider=none per bz 2417703), marker to /var, enables services.
  tmpfiles.d/cloudws-freeipa.conf: expanded (pki/, certmonger/local/,
    sssd ownership, conf.d 0600 enforcement, /etc/cloudws/ dir).

docs/COMPOSEFS-VERIFICATION.md: chain diagram, tier explanations,
  Tier B no-op caveat, Tier C false-positive escape hatch, /etc drift note.
docs/SECUREBOOT.md: CloudWS-1 vs CloudWS-2 paths, MokManager walkthrough,
  TPM2 PCR7+14 re-seal commands, key rotation, OVMF testing.

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
