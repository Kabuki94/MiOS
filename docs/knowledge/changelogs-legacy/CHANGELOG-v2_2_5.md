# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# MiOS v2.1.0 - CI lowercase + cloud-ws.ps1 token-leak fix

## Two bugs, independent, both critical

### Bug 1: CI push failed with "repository name must be lowercase"

The build-sign.yml workflow used `ghcr.io/${{ github.repository_owner }}`
which resolves to `ghcr.io/Kabuki94` (capital K). Container registry
references MUST be lowercase per OCI spec and GHCR enforcement.

Error from the push step:
```
Error: invalid reference format: repository name must be lowercase
Process completed with exit code 125.
```

The image BUILT successfully (the entire buildah bud step ran clean).
The image just never made it to the registry.

### Bug 2: cloud-ws.ps1 leaked the GitHub PAT to the terminal

Line 89 had:
```
            $buf = Read-Host -MaskInput
```

`-MaskInput` was added in PowerShell 7.1. On Windows PowerShell 5.1
(the default `powershell.exe` on every Windows system), `-MaskInput`
is not a recognized parameter - it gets parsed as a positional argument
to `-Prompt`, becoming part of the literal prompt text. The user types
their token and it's echoed verbatim to the console.

Screenshot evidence: the user's PAT `ghp_...` was visible in plain
text in the prompt output.

## Fixes

### workflow

Added a `Compute lowercase registry path` step that uses bash
parameter expansion `${GITHUB_REPOSITORY_OWNER,,}` (lowercase
expansion) to produce `ghcr.io/kabuki94/mios` as a step
output. All subsequent steps (push, sign, attest) reference
`steps.reg.outputs.full_ref` so there is exactly one source of
truth for the registry path.

### cloud-ws.ps1

Replaced the single `Read-Host -MaskInput` call with a
version-aware dispatch:

```
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $buf = Read-Host -MaskInput
} else {
    $sec  = Read-Host -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try   { $buf = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
```

On PS 7.1+: uses native `-MaskInput`.
On PS 5.1:  uses `-AsSecureString` + Marshal::PtrToStringBSTR to
            extract plaintext after masked entry. The BSTR is freed
            via `ZeroFreeBSTR` so the plaintext isnt left in
            unmanaged memory after the function returns.

## Reminder about the leaked token

Anyone who saw the screenshot or the local terminal output should
immediately REVOKE the leaked token:

  https://github.com/settings/tokens

Classic PATs (ghp_ prefix) grant broad access until expiry. Even if
the token has short scope, assume it is compromised and rotate.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
