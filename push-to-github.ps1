# ============================================================================
# push-to-github.ps1
# ----------------------------------------------------------------------------
# DEPRECATED as of v2.1.6; will be removed in v2.2.0.
#
# Forwards all invocations to push-v2.1.6.ps1, which uses `git commit -F`
# via a tempfile and correctly handles multi-word commit messages. The old
# body had `git commit -m $msg` which unquote-split on whitespace.
# ============================================================================
Write-Warning "push-to-github.ps1 is deprecated as of v2.1.6."
Write-Warning "Forwarding to push-v2.1.6.ps1 - please update your references."

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$forward   = Join-Path $scriptDir 'push-v2.1.6.ps1'

if (-not (Test-Path -LiteralPath $forward)) {
    Write-Error "push-v2.1.6.ps1 not found at $forward. Please use the v2.1.6 flatpack push script instead."
    exit 1
}

& $forward @args
exit $LASTEXITCODE
