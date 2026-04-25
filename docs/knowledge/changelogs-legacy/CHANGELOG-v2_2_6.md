# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# MiOS v2.1.0 - Restore UTF-8 BOM on .ps1 files

## What went wrong

v2.1.0 patched cloud-ws.ps1 to fix the Read-Host -MaskInput token leak.
My Write-Utf8NoBom helper wrote the file back WITHOUT a BOM. But
cloud-ws.ps1 is full of box-drawing (U+2500, U+2550), check-mark
(U+2713), em-dash (U+2014), and arrow (U+2192) characters used in
banners and menus.

On Windows PowerShell 5.1 (default powershell.exe), .ps1 files
without a BOM are parsed as CP1252, not UTF-8. The multi-byte UTF-8
sequences get shredded: for example, U+2500 (horizontal line) is
`E2 94 80` in UTF-8, but byte `0x94` in CP1252 is the right-double-
quote character, which prematurely terminates whatever string
contains it. Cascade of parse errors follows.

Evidence from the failure output:
```
Unexpected token 'EURO"*70)" in expression or statement.
Missing closing ')' in subexpression.
The token '&&' is not a valid statement separator in this version.
Unexpected token 'crypt.mksalt' in expression or statement.
```

Every one of those was a downstream parse error triggered by
mid-string termination from a misinterpreted UTF-8 byte.

## The fix

Simple: re-add the UTF-8 BOM to any .ps1 file with non-ASCII
content. The BOM signals UTF-8 to Windows PowerShell 5.1. With
BOM, PS 5.1 parses the file as UTF-8 and the box-drawing characters
render correctly.

No content changes - just the 3-byte `EF BB BF` prefix restored
on files that had it before my v2.1.0 overwrite stripped it.

## Detection logic

The script scans every `.ps1` in the repo, reads raw bytes:

- If the file contains any byte >= 0x80 (non-ASCII) AND does NOT
  start with `EF BB BF` -> BOM added.
- If it already has a BOM or is pure ASCII -> left alone.

## Going forward

Future push scripts will:

- Keep using no-BOM for newly-created files (no BOM for ASCII).
- Preserve the existing BOM when editing files that had one.
- Add BOM when patching .ps1 files that contain non-ASCII content,
  since those files are read by Windows PowerShell 5.1 at runtime.

Alternative option considered and rejected: replace all the box-drawing
and check-mark characters in cloud-ws.ps1 with ASCII equivalents
(`-` for `--`, `[OK]` for check-mark, etc.). This would make the script
BOM-independent but loses the user's banner aesthetic. BOM restoration
is less invasive.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
