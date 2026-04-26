<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# 🌐 MiOS — Cloud Native Operating System
```json:knowledge
{
  "summary": "> **Proprietor:** Kabu.ki",
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
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
---
description: Run the full CI lint pipeline locally — PowerShell-native on Windows, no external WSL popups
---

Run every linter that `.github/workflows/pr-lint.yml` runs, using
PowerShell on Windows or native shell on Linux. **Do not** invoke bare
`bash` on Windows — it routes through `wsl.exe` and spawns external
terminal windows. Use `pwsh -Command` for cross-platform, or explicit
`wsl -e bash -c '...'` when a tool genuinely requires Linux.

## 1. shellcheck on every `*.sh`

PowerShell (Windows):
```powershell
Get-ChildItem -Recurse -File -Filter '*.sh' |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object { shellcheck -S warning $_.FullName }
```

Treat **SC2038, SC2206, SC2013, SC2012, SC2155, SC2015, SC2059,
SC2162, SC2010, SC2054** as **fatal** — the CI runner does.

## 2. shellcheck on extensionless scripts

```powershell
@(
  'scripts/mios-motd',
  'scripts/mios-test',
  'scripts/mios-toggle-headless',
  'scripts/mios-grd-setup',
  'system_files/usr/libexec/mios/libvirtd-firstboot',
  'system_files/usr/libexec/mios/role-apply',
  'system_files/usr/libexec/mios/select-cdi-spec',
  'system_files/usr/libexec/mios/wsl-firstboot',
  'system_files/usr/libexec/mios-boot-diag',
  'system_files/usr/libexec/mios-flatpak-install',
  'system_files/usr/bin/gamescope-session-steam',
  'system_files/usr/bin/steamos-session-select',
  'system_files/usr/local/bin/mios-ceph',
  'system_files/usr/local/bin/mios-ceph-bootstrap',
  'system_files/usr/local/bin/phosh-session-wrapper'
) | Where-Object { Test-Path $_ } |
    ForEach-Object { shellcheck -S warning $_ }
```

## 3. hadolint on the Containerfile

```powershell
hadolint Containerfile
```

## 4. yamllint on workflows + configs

```powershell
yamllint .github/workflows/ renovate.json image-versions.yml
```

## 5. TOML validation

```powershell
Get-ChildItem -Recurse -File -Filter '*.toml' |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object { taplo check $_.FullName }
```

Plus the `kargs.d/*.toml` semantic check — Python with inline string
assembly, which runs cleanly under PowerShell:

```powershell
Get-ChildItem kargs.d -Filter '*.toml' | ForEach-Object {
  $p = $_.FullName
  python -c "import tomllib,pathlib,sys; d=tomllib.loads(pathlib.Path(r'$p').read_text()); assert 'kargs' in d and isinstance(d['kargs'],list) and all(isinstance(x,str) for x in d['kargs']) and 'delete' not in d, 'invalid kargs.d'; print(r'$p' + ': ok')"
}
```

## 6. PSScriptAnalyzer on every `*.ps1`

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery -Severity Error,Warning
```

Treat **PSAvoidUsingInvokeExpression** and
**PSAvoidUsingEmptyCatchBlock** as fatal (CLAUDE.md §3.8).

## 7. `bootc container lint` — only on Linux

`bootc` doesn't run natively on Windows. On a Linux host or inside the
integrated WSL (explicit `wsl -e bash -c` so it stays embedded):

```
wsl -e bash -c "bootc container lint --image ghcr.io/kabuki94/mios:latest 2>&1 | tee build/bootc-lint.log"
```

Scan output for:
- `Parsing .../kargs.d/...` errors (rule §3.3)
- `composefs` verification failures

## 8. Summary

Print per-tool results as:

```
shellcheck:        N files, X errors, Y warnings
hadolint:          N issues
yamllint:          N issues
taplo:             N TOML files, X invalid
kargs.d validator: N files, X invalid
PSScriptAnalyzer:  N scripts, X errors, Y warnings
bootc lint:        <pass/fail/skipped>
```

If anything failed → **DO NOT PUSH**. Otherwise → **Safe to push.**

---

## Host-OS detection

At the top of the run, detect host OS so the linter invocations don't
crash on the wrong platform:

```powershell
$isWin = $IsWindows -or ($env:OS -eq 'Windows_NT')
```

Use `$isWin` to branch: skip `bootc lint` on Windows, skip
`PSScriptAnalyzer` on pure Linux if `pwsh` isn't installed.

**Hard rule for this command:** never invoke bare `bash` on Windows.
Always `pwsh -Command` for cross-platform, or `wsl -e bash -c '...'`
when a tool truly needs a Linux environment (like `bootc`). Bare
`bash` on Windows = `C:\Windows\System32\bash.exe` = external WSL
popup window, which defeats the whole point of running these checks
inside the integrated terminal.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
