# GitHub Copilot Instructions — CloudWS-bootc

> This file is read automatically by **GitHub Copilot Chat** and
> **Copilot code-generation** when working inside this repository
> (opt-in via `github.copilot.chat.codeGeneration.useInstructionFiles`
> in `.vscode/settings.json`).
>
> The authoritative per-repo guide is [`CLAUDE.md`](../CLAUDE.md).
> This file is a condensed reminder for Copilot specifically, because
> Copilot has produced the most build-breaking suggestions on this
> repo historically — particularly on `kargs.d/*.toml` files.

---

## Project in one paragraph

CloudWS-bootc is a Fedora bootc–based, self-building, immutable
workstation OS. Two variants (CloudWS-1 on Fedora Rawhide,
CloudWS-2 on Universal Blue `ucore-hci:stable-nvidia`) share one
Containerfile, one package manifest (`docs/PACKAGES.md`), one overlay
tree (`system_files/`), and numbered provisioning scripts
(`scripts/01-*.sh` through `47-*.sh`). Published at
`ghcr.io/kabuki94/cloudws-bootc:latest`. Target hardware: AMD Ryzen 9
9950X3D + NVIDIA RTX 4090. Stack: GNOME Wayland, KVM/QEMU/VFIO,
Podman, K3s, Ceph, Pacemaker HA, CrowdSec, Gamescope Steam Session.

---

## Hard rules — violating any of these breaks the build

### `kargs.d/*.toml` — this is where Copilot gets it wrong most often

**Only this format is valid:**

```toml
# Comment describing the drop-in.
kargs = [
    "key=value",
    "flag",
]
```

Copilot frequently suggests any of the following — **all are wrong**
and will cause `bootc container lint` to fail the build:

```toml
[kargs]                          # NO — no section header
kargs = [ ... ]

kargs = [ ... ]
delete = [ ... ]                 # NO — no delete key exists in bootc

kargs = [ ... ]
delete_kargs = [ ... ]           # NO — same

[[kargs]]                        # NO — not an array-of-tables

kargs.append = [ ... ]           # NO — no dotted keys
```

If you catch yourself writing any of these shapes, stop and use the
flat top-level `kargs = [ ... ]` array instead.

### Containerfile / DNF

- **Do not** `dnf install kernel` or `dnf upgrade kernel` inside the
  container. Only install `kernel-modules-extra`, `kernel-devel`,
  `kernel-headers` etc.
- **Do not** suggest `--squash-all` on `podman build` — it strips the
  OCI metadata bootc requires.
- `COPY PACKAGES.md` must be `COPY docs/PACKAGES.md /ctx/PACKAGES.md`.
  The file moved out of the repo root in v2.3.5.

### Bash

- **Do not** suggest `((VAR++))`. Under `set -euo pipefail` it exits
  the script when `VAR=0`. Use `VAR=$((VAR + 1))`.
- Prefer `compgen -G "/dev/nvidia*" >/dev/null` over
  `ls /dev/nvidia* | grep -q .`.
- Prefer `find ... -exec cp {} dst \;` over `find ... | xargs cp`.
- Prefer `for u in $(< file)` over `for u in $(cat file)`.
- Quote variables. Use `read -r` / `read -ra`.
- Separate declaration from assignment for command substitutions:
  `local KVER; KVER=$(uname -r)`.
- Replace `A && B || C` with explicit `if/then/else`.

### GNOME / theming

- **Do not** suggest `GTK_THEME=Adwaita:dark`. Use
  `ADW_DEBUG_COLOR_SCHEME=prefer-dark`.
- `/etc/dconf/profile/user` and `/etc/dconf/profile/gdm` must exist.
- Never put both `categories=` and `apps=` in a dconf app folder.
- `gnome-session-xsession` does not exist in Fedora — don't suggest it.
- `xorgxrdp` and `xorgxrdp-glamor` conflict. Use only
  `xorgxrdp-glamor`.

### NVIDIA / VM

- `ucore-hci:stable-nvidia` ships NVIDIA kmods that udev coldplugs in
  VMs. Blacklist by default; unblacklist only on bare metal via
  `34-gpu-detect.sh`.
- Don't unconditionally ship `nvidia-drm.modeset=1` /
  `nvidia-drm.fbdev=1` in kargs — gate on hardware.

### PowerShell

- **Do not** suggest `Invoke-Expression` on downloaded content.
  Use write-to-temp + `& $tmp.FullName` + remove.
- **Do not** suggest empty `catch {}`.
- Use `Read-Host -MaskInput` or `[SecureString]` for secrets.
- Push scripts **clone** the existing repo; never `git init`.

### Packages

- `docs/PACKAGES.md` is the single source of truth. Edits are
  surgical — never regenerate the file wholesale.
- The `gnome-core-apps` block is commented out by default. Leave it
  commented.

---

## Deliverable format

- **Complete replacement files only.** Not patches. Not "edit this
  section". Not "paste this into X". The whole file, every time.
- Release deliverables are **PowerShell push scripts** named
  `push-vX.Y.Z.ps1` that clone the repo, copy companion files in,
  commit with a structured message, and push to `main`.
- Never `git init`. Never push without human review.
- Don't delete files that weren't explicitly targeted.

---

## Communication

Kabu is the sole developer. Direct, expectation-driven. ALL CAPS and
exclamation points signal a hard correction — fix scope immediately
and redeliver complete replacement files.

---

*See `CLAUDE.md` for the full rationale. When this file disagrees
with `CLAUDE.md`, `CLAUDE.md` wins.*
