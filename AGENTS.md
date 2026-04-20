# AGENTS.md — CloudWS-bootc

> This is the generic-agent instruction file, following the emerging
> **`AGENTS.md` standard** (OpenAI Codex, Cursor, Aider, Continue.dev,
> and a growing list of agentic coding tools read this file on entry).
> Claude Code reads `CLAUDE.md`; Gemini reads `GEMINI.md`; this file
> catches everything else.

---

## 🤖 AI AGENT DIRECTIVES

**ALL AGENTS (Claude, Gemini, etc.) MUST READ THE FOLLOWING BEFORE EACH TURN:**

1.  **[`.ai-context/AI-README.md`](./.ai-context/AI-README.md)** — Unified entry point and core AI laws.
2.  **[`.ai-context/ai-journal.md`](./.ai-context/ai-journal.md)** — Mandatory chronological ledger of all AI actions.

**Violation of the Journaling Law is a critical failure.**

---

## Source of truth

**Read [`CLAUDE.md`](./CLAUDE.md) first.** It contains:

1. Project identity (Fedora bootc, not Arch, not Nix)
2. Repo layout
3. Hard build rules — non-negotiable
4. Deliverable expectations
5. What not to do

This file is a short-form mirror. If it and `CLAUDE.md` disagree,
`CLAUDE.md` wins.

---

## One-paragraph project summary

CloudWS-bootc is a self-building, immutable cloud-native workstation
OS built on Fedora bootc. Two variants — CloudWS-1 (Fedora Rawhide
base) and CloudWS-2 (Universal Blue ucore-hci:stable-nvidia, primary) —
share one Containerfile, one package manifest (`docs/PACKAGES.md`),
one overlay tree (`system_files/`), and a family of numbered
provisioning scripts (`scripts/01-*.sh` through `47-*.sh`). The
published image at `ghcr.io/kabuki94/cloudws-bootc:latest` is both the
workstation OS and its own builder. Target hardware is AMD Ryzen 9
9950X3D + NVIDIA RTX 4090. The full stack includes GNOME Wayland,
KVM/QEMU/VFIO, Podman, K3s, Ceph, Pacemaker/Corosync HA, CrowdSec,
Gamescope Steam Session, Waydroid, Looking Glass, xRDP, and FreeIPA/SSSD.

---

## Rules of engagement (short form)

### Build & scripting

- `kargs.d/*.toml` — flat top-level `kargs = [...]` array. No
  `[kargs]` section header. No `delete` sub-key. Bootc rejects
  anything else.
- Never upgrade `kernel` / `kernel-core` inside the container; only
  add `kernel-modules-extra`, `kernel-devel`, etc.
- No `--squash-all` on `podman build`. It strips OCI metadata bootc
  needs.
- Under `set -euo pipefail`, never use `((VAR++))`. Use
  `VAR=$((VAR + 1))`.
- Follow shellcheck. CI treats SC2038 as fatal.
- Prefer `compgen -G`, `find -exec`, `for u in $(< file)`, and
  `read -ra` patterns.
- `/etc/skel/.bashrc` is written **before** `useradd -m`.
- `GTK_THEME=Adwaita:dark` is banned — use
  `ADW_DEBUG_COLOR_SCHEME=prefer-dark`.

### PowerShell

- No `Invoke-Expression` on downloaded content — write to a temp file,
  `& $tmp.FullName`, remove.
- No empty `catch {}` blocks.
- Secrets via `Read-Host -MaskInput` or `[SecureString]`. Never echo.
- Push scripts **clone the existing repo**, never `git init`.

### Deliverables (the part everyone gets wrong)

- **Complete replacement files only.** Not diffs, not patches, not
  "edit this section".
- **PowerShell push script** that clones → copies files atomically →
  commits with a structured message → pushes.
- Companion files go in the same directory as the push script.
- Do not delete files that weren't explicitly targeted.
- If you're deliberately excluding part of an input (e.g. broken
  Copilot-authored TOML), state what you excluded and why.

### Verification

- Before suggesting a fix, **clone the repo and look at the real
  file**. The layout changes (e.g. `PACKAGES.md` moved to
  `docs/PACKAGES.md` in v0.1.8).
- Simulate string replacements against actual content before
  shipping them.

### Communication

- Kabu (the sole developer) uses ALL CAPS and exclamation points when
  prior guidance wasn't followed. Treat this as a hard correction —
  acknowledge, fix scope, redeliver.
- Execute completely. Don't ask clarifying questions on clear
  requests.
- Don't narrate process. Deliver the artifact, explain briefly after.

---

## Safe vs. unsafe commands (for agents with tool-call capability)

### Safe to auto-run

- `git status`, `git log`, `git diff`, `git show`, `git branch -a`
- `ls`, `find`, `grep`, `rg`, `cat` on repo files
- `shellcheck <file>`, `hadolint Containerfile`, `yamllint <file>`
- `podman build --no-cache --target ctx .` (build context only, not full image)
- Dry-run linters: `shfmt -d`, `prettier --check`

### Require explicit approval before running

- `git push` (always)
- `git commit` (only via push script path)
- `podman push`
- Full `podman build` of the main stage
- `bootc-image-builder` invocations
- Anything that writes outside the repo working tree
- Anything that touches `~/.docker/config.json`, GitHub tokens, or
  cosign keys
- Execution of any `.ps1` file on the host
- Editing `docs/PACKAGES.md`, `VERSION`, or `CHANGELOG.md`

---

## Useful entry points

| Task | Entry point |
|------|-------------|
| Orientation | `README.md` then `CLAUDE.md` |
| Package changes | `docs/PACKAGES.md` + `scripts/lib/packages.sh` |
| Build logic | `Containerfile` + `scripts/NN-*.sh` |
| Kernel args | `kargs.d/` (one flat TOML per concern) |
| Overlays | `system_files/etc` / `system_files/usr` |
| CI | `.github/workflows/*.yml` |
| Historical audits | `.ai-context/knowledge-base.md` (append-only) |
| Research | `docs/knowledge/` |

---

*Last updated in lock-step with the CloudWS-bootc AI-tooling export.
This file is intentionally short; when in doubt, go to `CLAUDE.md`.*
