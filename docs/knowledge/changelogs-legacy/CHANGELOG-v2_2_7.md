# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# MiOS v2.1.0 - ASCII-only install.ps1 + preflight.ps1

## Bug

v2.1.0 added UTF-8 BOMs to every .ps1 file with non-ASCII content so that
cloud-ws.ps1 (loaded from disk) would parse under Windows PowerShell 5.1.
That fix was correct for disk-loaded scripts. It was WRONG for scripts
consumed via `irm | iex`, which is how install.ps1 and preflight.ps1 are
used:

```
irm https://raw.githubusercontent.com/Kabuki94/MiOS/main/install.ps1 | iex
```

When `Invoke-RestMethod` receives a file starting with `EF BB BF`, the
BOM bytes are decoded into a literal U+FEFF character in the returned
string. `Invoke-Expression` then tries to parse a script whose first
character is U+FEFF, and errors out:

```
The term 'U+FEFF$ErrorActionPreference' is not recognized...
```

## Policy (now hard rule)

| Consumption path       | BOM allowed? | Non-ASCII allowed? |
|------------------------|--------------|---------------------|
| Loaded from DISK by PS 5.1 | YES (required if non-ASCII) | YES |
| Consumed via `irm \| iex`   | NO          | NO (safer)          |

`install.ps1` and `preflight.ps1` are in the second category. They must
be pure ASCII with no BOM.

## Fix

Rewrote both files with ASCII-only decorations:

- `+==============+` / `|` instead of `+==================+` / `|` (plain characters now)
- `---Section---` instead of Unicode box-drawing section headers
- `[OK]` / `[MISSING]` / `[X]` / `[WARN]` instead of check-mark/cross/warning glyphs
- `--` (two hyphens) instead of em-dash

Zero logic change. All menu prompts, all checks, all winget invocations,
all Write-Host colors identical.

## Files touched this release

- `install.ps1` - rewritten ASCII-only, no BOM
- `preflight.ps1` - rewritten ASCII-only, no BOM

## Files explicitly NOT touched (stay with BOM)

- `cloud-ws.ps1` - loaded from disk after clone; retains BOM from v2.1.0
- `push-to-github.ps1` - loaded from disk; retains BOM from v2.1.0

## Going forward

Every push script I generate that creates/edits .ps1 files in the repo
will classify by consumption path:

- irm-consumed: ASCII-only, no BOM, strict enforcement at write time
- disk-loaded: BOM preserved; non-ASCII allowed if BOM present

The v2.1.0 push script includes a post-write sanity check that reads
install.ps1 and preflight.ps1 back and WARNs if it detects BOM or
non-ASCII bytes.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
