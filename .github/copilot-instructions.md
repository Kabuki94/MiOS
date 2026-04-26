# GitHub Copilot Instructions — MiOS

> This file is read automatically by **GitHub Copilot Chat** and
> **Copilot code-generation** when working inside this repository
> (opt-in via `github.copilot.chat.codeGeneration.useInstructionFiles`
> in `.vscode/settings.json`).
>
The authoritative per-repo guide is [`AI.md`](../AI.md).
This file is a condensed reminder for Copilot specifically, because
Copilot has produced the most build-breaking suggestions on this
repo historically — particularly on `kargs.d/*.toml` files.

---

## 🤖 AI AGENT DIRECTIVES

**ALL AGENTS (Claude, Gemini, Copilot, Cursor, Windsurf, Cline, etc.) MUST READ THE FOLLOWING BEFORE EACH TURN:**

1.  **[`AI.md`](../AI.md)** — Unified entry point and core AI laws.
2.  **[`journal.md`](../.claude/memories/journal.md)** — Mandatory chronological ledger of all AI actions.

**Violation of the Journaling Law is a critical failure.**

---

## 🚨 AI SYSTEM LAW (CRITICAL DIRECTIVES FOR ALL AGENTS) 🚨

**The following directives are ABSOLUTE LAW for ALL AI Agents, Models, and APIs interacting with this workspace:**

1. **MANDATORY JOURNALING:** Every single action, thought, learning, discovery, or suggested alternative MUST be timestamped, labeled with the acting agent's identity, and permanently logged as a file diff appending to `.ai-context/ai-journal.md`. Ephemeral chat window logging without file persistence is a STRICT VIOLATION.
2. **NO ASSUMPTIONS:** MiOS is an immutable, container-native OS. You must respect `bootc`, `ComposeFS`, and `Quadlet` invariants. Do NOT suggest traditional mutable Linux commands (e.g., `dnf install` at runtime).
3. **DIFF FORMATTING:** All code modifications must be delivered as complete, unified file diffs targeting the exact absolute paths.

**By processing this file, you acknowledge and are bound by these laws.**

---

## Project in one paragraph

MiOS is a Fedora bootc–based, self-building, immutable
workstation OS. Two variants (MiOS-1 on Fedora Rawhide,
MiOS-2 on Universal Blue `ucore-hci:stable-nvidia`) share one
Containerfile, one package manifest (`docs/PACKAGES.md`), one overlay
tree (`system_files/`), and numbered provisioning scripts
(`scripts/01-*.sh` through `47-*.sh`). Published at
`ghcr.io/kabuki94/mios-bootc:latest`. Target hardware: AMD Ryzen 9
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
  The file moved out of the repo root in v2.1.0.

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
- Release deliverables must be pushed using the single central **PowerShell push script**
  named `push-to-github.ps1` that clones the repo, copies files in,
  commits with a structured message, and pushes to `main`. Do NOT create `push-vX.Y.Z.ps1` variants.
- Never `git init`. Never push without human review.
- Don't delete files that weren't explicitly targeted.

---

## Communication

Kabu is the sole developer. Direct, expectation-driven. ALL CAPS and
exclamation points signal a hard correction — fix scope immediately
and redeliver complete replacement files.

---

*See `CLAUDE.md`. When this file disagrees with `CLAUDE.md`, `CLAUDE.md` wins.*
