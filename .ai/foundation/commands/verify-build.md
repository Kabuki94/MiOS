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
description: Dry-run the MiOS hard-rules audit against the working tree or a proposed change — PowerShell-native, no WSL popups
argument-hint: [file-or-directory]
---

Run the MiOS hard-rules audit defined in `SYSTEM.md` §3
against `$1` (or the whole working tree if no argument given). Report
violations by rule number so they trace back to the SYSTEM.md section.

**Never invoke bare `bash` on Windows** — it spawns external WSL
windows. Use PowerShell-native pipelines, or `Select-String` in place
of `grep`, or `Get-ChildItem | Where-Object` in place of `find`.

Check every item. Do not skip any.

### §3.1 — Containerfile / DNF

Search `Containerfile` for kernel upgrades (only -modules-extra,
-devel, -headers allowed):
```powershell
Select-String -Path Containerfile -Pattern 'dnf\s+install.*\bkernel(\s|$|-core)'
```

Search for `--squash-all`:
```powershell
Get-ChildItem -Recurse -File -Include '*.sh','*.yml','*.yaml','*.ps1','Containerfile','Justfile' |
  Select-String -Pattern '--squash-all'
```

### §3.2 — Bash under set -euo pipefail

```powershell
Get-ChildItem -Recurse -File -Filter '*.sh' |
  Where-Object { (Get-Content $_ -Raw) -match 'set\s+-[eu]+o?' } |
  Select-String -Pattern '\(\(\w+\+\+\)\)|\(\(\w+--\)\)'
```

Run shellcheck on every changed `*.sh` (see `/lint-all`). SC2038,
SC2206, SC2013, SC2012, SC2155, SC2015, SC2059, SC2162, SC2010, SC2054
are blockers.

### §3.3 — kargs.d TOML

For every `kargs.d/*.toml` and `overlay/usr/lib/bootc/kargs.d/*.toml`:
```powershell
Get-ChildItem -Recurse -Filter '*.toml' -Path kargs.d,overlay/usr/lib/bootc/kargs.d -ErrorAction SilentlyContinue |
  ForEach-Object {
    $p = $_.FullName
    python -c "import tomllib,pathlib; d=tomllib.loads(pathlib.Path(r'$p').read_text()); assert 'kargs' in d, 'missing kargs'; assert isinstance(d['kargs'],list), 'kargs not list'; assert all(isinstance(x,str) for x in d['kargs']), 'non-string entries'; assert 'delete' not in d and 'delete_kargs' not in d, 'delete key present'; print(r'$p' + ' ok')"
  }
```

### §3.4 — GNOME / theming

```powershell
Get-ChildItem -Recurse system_files,scripts |
  Select-String -Pattern 'GTK_THEME.*Adwaita:dark'

Test-Path overlay/etc/dconf/profile/user
Test-Path overlay/etc/dconf/profile/gdm

Get-ChildItem -Recurse system_files,scripts |
  Select-String -Pattern 'gnome-session-xsession'

Select-String -Path specs/PACKAGES.md -Pattern '^\s*xorgxrdp\b(?!-glamor)'
```

### §3.5 — NVIDIA / VM gating

```powershell
Test-Path overlay/etc/modprobe.d/mios-nvidia-blacklist.conf
Test-Path automation/34-gpu-detect.sh

Get-ChildItem -Recurse -Filter '*.toml' kargs.d,bib-configs,overlay/usr/lib/bootc/kargs.d |
  Select-String -Pattern 'nvidia-drm\.(modeset|fbdev)='

Get-ChildItem -Recurse -Filter '*.service' system_files,systemd |
  Where-Object { (Get-Content $_ -Raw) -match 'mios-ceph' } |
  Select-String -Pattern 'ConditionVirtualization='
```

### §3.6 — User setup

```powershell
Select-String -Path automation/31-user.sh -Pattern 'useradd'
Get-ChildItem -Recurse -Include '*.sh','*.ps1' |
  Select-String -Pattern '(token|password)\s*=\s*"[^"$]' -CaseSensitive:$false
```

### §3.7 — SELinux

```powershell
Get-ChildItem -Recurse -Filter '*.te' |
  Where-Object { (Get-Content $_).Count -gt 15 }
```

### §3.8 — PowerShell

```powershell
Get-ChildItem -Recurse -Filter '*.ps1' |
  Select-String -Pattern 'Invoke-Expression|catch\s*\{\s*\}|ConvertTo-SecureString.*-AsPlainText\s+["'']'
```

### §3.9 — Package manifest

```powershell
Select-String -Path specs/PACKAGES.md -Pattern '```packages-'

# Ensure gnome-core-apps block is fully commented
$inBlock = $false
$violation = $false
Get-Content specs/PACKAGES.md | ForEach-Object {
  if ($_ -match '```packages-gnome-core-apps') { $inBlock = $true; return }
  if ($inBlock -and $_ -match '^```') { $inBlock = $false; return }
  if ($inBlock -and $_ -notmatch '^\s*(#|$)') { $violation = $true; Write-Host "UNCOMMENTED: $_" }
}
```

### Output format

Print one line per finding:

```
[PASS/FAIL] §3.N rule-short-name  path:line  short description
```

Then a summary:

```
SUMMARY: X passed, Y failed, Z warnings.
```

If any FAIL: **DO NOT SHIP.**

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
