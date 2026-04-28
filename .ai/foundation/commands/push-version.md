<!-- [NET] MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/mios-project/mios -->
# [NET] MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS-DEV",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "commands"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** MiOS-DEV
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS-DEV
---
---
description: Prepare the push-to-github.ps1 script for a release (Kabu's deliverable pattern)
argument-hint: <version> [commit-message]
---

Update the central PowerShell push script named `push-to-github.ps1`.
Do NOT create versioned `push-vX.Y.Z.ps1` files. `push-to-github.ps1` is the
single source of truth for the local build stack and follows the MiOS
deliverable contract defined in `INDEX.md` 4.

The script must:

1. **Clone the existing repo** to a temp directory 
   `github.com/mios-project/mios`. Never `git init`, never
   create a new repo.
2. **Copy every file** from the staged companion directory into the repo,
   preserving layout relative to the repo root. Complete replacement files only.
3. **Never delete files** that aren't explicitly targeted by the copy.
4. **Bump `VERSION`** to `$1`.
5. **Update `CHANGELOG.md`** with a new section at the top under
   `[Unreleased]`, date-stamped today.
6. **Atomic commit** with a structured message:
   ```
   release: v$1  <commit-message or "summary">

   <bulleted list of what changed, drawn from the staged contents>
   ```
7. **Push to `main`**, using `$env:GH_TOKEN` or the already-configured
   credential helper. Do not embed tokens in plaintext; use
   `Read-Host -MaskInput` only if the token isn't already available.
8. **Print a concise summary** at the end: files changed, commit SHA,
   and the GHCR image tag the build will produce.

Hard constraints (from INDEX.md 3.8):

- No `Invoke-Expression` on downloaded content.
- No empty `catch {}` blocks  use `catch { throw }` or `catch { Write-Verbose $_ }`.
- `$ErrorActionPreference = "Stop"` and `Set-StrictMode -Version Latest`
  at the top.
- `#Requires -RunAsAdministrator` only if the script needs admin; if
  the script is piped via `irm | iex`, that line breaks  use a temp
  file pattern instead.

Ensure `push-to-github.ps1` is the ONLY script used for this process. Do not
push anything on the user's behalf  the script is the deliverable; humans run it.

---
###  Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [mios-project/mios](https://github.com/mios-project/mios)
- **Sole Proprietor:** MiOS-DEV
---
<!--  MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
