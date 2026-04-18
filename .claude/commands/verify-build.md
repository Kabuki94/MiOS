---
description: Dry-run the CloudWS-bootc hard-rules audit against the current working tree or a proposed change
argument-hint: [file-or-directory]
---

Run the CloudWS-bootc hard-rules audit defined in `CLAUDE.md` §3
against `$1` (or the whole working tree if no argument given). Report
violations by rule number so they trace back to the CLAUDE.md section.

Check every item. Do not skip any.

### §3.1 — Containerfile / DNF

- Search `Containerfile` for `dnf install .* kernel[^-]` (upgrading the
  kernel itself). Flag matches — only `-modules-extra`, `-devel`,
  `-headers` etc. are allowed.
- Search for `--squash-all` in `Containerfile`, `Justfile`,
  `cloud-ws.ps1`, and `scripts/**/*.sh`. Any occurrence is a hard fail.
- Search `.github/workflows/**/*.yml` for `--squash-all` too.

### §3.2 — Bash under set -euo pipefail

- In every `*.sh` file that contains `set -euo pipefail` (or `set -e`
  together with `set -u`), search for `((VAR++))` or `((VAR--))`.
  Flag all matches.
- Run `shellcheck -S warning` on every `*.sh` file changed relative to
  `main`. Treat SC2038, SC2206, SC2013, SC2012, SC2155, SC2015, SC2059,
  SC2162, SC2010, SC2054 as blockers.

### §3.3 — kargs.d TOML

- For every `kargs.d/*.toml`, assert:
  - Top-level `kargs = [ ... ]` array only.
  - No `[kargs]` section header.
  - No `delete` or `delete_kargs` sub-key.
  - Values are all strings.
  - No trailing commas, no inline tables.

### §3.4 — GNOME / theming

- `grep -rn "GTK_THEME.*Adwaita:dark" system_files/ scripts/` — any
  match is a hard fail.
- Verify `/etc/dconf/profile/user` and `/etc/dconf/profile/gdm` exist
  under `system_files/etc/dconf/profile/`.
- Search dconf app-folder files for `categories=` and `apps=` coexistence.
- Search `scripts/` and `system_files/` for `gnome-session-xsession`.
- Search for both `xorgxrdp` and `xorgxrdp-glamor` in
  `docs/PACKAGES.md`. Flag if both present.

### §3.5 — NVIDIA / VM gating

- Check `34-gpu-detect.sh` removes the NVIDIA module blacklist on bare
  metal.
- Check `system_files/etc/modprobe.d/` contains a default NVIDIA
  blacklist.
- Search `kargs.d/` for `nvidia-drm.modeset=1` — if present, verify
  hardware gating exists.
- Check any `.service` with `cloudws-ceph` in the name uses
  `ConditionVirtualization=no`.

### §3.6 — User setup

- Verify `/etc/skel/.bashrc` is written before `useradd -m` in
  `scripts/31-user.sh` and any other script that calls `useradd`.
- Grep for plaintext tokens / passwords in shell scripts and
  PowerShell scripts: `token = "`, `password = "`,
  `Write-Host .*token`, `echo .*PAT`.

### §3.7 — SELinux

- Check `scripts/37-selinux.sh` (and any sibling) for monolithic `.te`
  modules — flag any single `.te` with more than ~5 rules.

### §3.8 — PowerShell

- `grep -rn "Invoke-Expression" *.ps1 scripts/*.ps1` — flag all.
- `grep -rn "catch\s*{\s*}" *.ps1 scripts/*.ps1` — flag all.
- `grep -rn "ConvertTo-SecureString.*-AsPlainText" *.ps1` — flag all
  that pass a literal (not a variable).

### §3.9 — Package manifest

- `docs/PACKAGES.md` fenced blocks tagged `packages-<category>` must
  be parseable. Run `scripts/lib/packages.sh --validate` if it exists,
  else grep for malformed fence tags.
- `gnome-core-apps` block must be fully commented out.

### Output format

Print one line per finding:

```
[PASS/FAIL] §3.N rule-short-name  path:line  short description
```

Then a summary:

```
SUMMARY: X passed, Y failed, Z warnings.
```

If any FAIL, state clearly at the top: **DO NOT SHIP.**
