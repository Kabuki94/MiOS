---
description: Scaffold a push-vX.Y.Z.ps1 script for a release (Kabu's deliverable pattern)
argument-hint: <version> [commit-message]
---

Create a PowerShell push script named `push-v$1.ps1` at the export root
(not inside the repo) that follows the CloudWS-bootc deliverable
contract defined in `CLAUDE.md` §4.

The script must:

1. **Clone the existing repo** to a temp directory —
   `github.com/Kabuki94/CloudWS-bootc`. Never `git init`, never
   create a new repo.
2. **Copy every file** from a companion directory
   (`./push-v$1-files/`) into the repo, preserving layout relative
   to the repo root. Complete replacement files only.
3. **Never delete files** that aren't explicitly targeted by the copy.
4. **Bump `VERSION`** to `$1`.
5. **Update `CHANGELOG.md`** with a new section at the top under
   `[Unreleased]`, date-stamped today.
6. **Atomic commit** with a structured message:
   ```
   release: v$1 — <commit-message or "summary">

   <bulleted list of what changed, drawn from the companion-dir contents>
   ```
7. **Push to `main`**, using `$env:GH_TOKEN` or the already-configured
   credential helper. Do not embed tokens in plaintext; use
   `Read-Host -MaskInput` only if the token isn't already available.
8. **Print a concise summary** at the end: files changed, commit SHA,
   and the GHCR image tag the build will produce.

Hard constraints (from CLAUDE.md §3.8):

- No `Invoke-Expression` on downloaded content.
- No empty `catch {}` blocks — use `catch { throw }` or `catch { Write-Verbose $_ }`.
- `$ErrorActionPreference = "Stop"` and `Set-StrictMode -Version Latest`
  at the top.
- `#Requires -RunAsAdministrator` only if the script needs admin; if
  the script is piped via `irm | iex`, that line breaks — use a temp
  file pattern instead.

Name the script `push-v$1.ps1`. Put companion files in `push-v$1-files/`.
Do not push anything on the user's behalf — the script is the
deliverable; humans run it.
