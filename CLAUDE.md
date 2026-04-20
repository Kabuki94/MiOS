# CLAUDE.md — CloudWS-bootc

> This file is read automatically by **Claude Code** (CLI, VSCodium/VSCode
> extension, JetBrains extension, and Claude Code in Slack). It is the
> authoritative per-repo instruction file and takes precedence over any
> general assistant behaviour when working inside this repository.
>
> A mirror lives in `GEMINI.md` (for Gemini CLI) and `AGENTS.md` (generic
> agent standard, read by OpenAI Codex/Cursor/Aider). Keep them in sync —
> or rather, `GEMINI.md` and `AGENTS.md` should redirect to this file and
> only carry tool-specific deltas.

---

## 🤖 AI AGENT DIRECTIVES

**ALL AGENTS (Claude, Gemini, etc.) MUST READ THE FOLLOWING BEFORE EACH TURN:**

1.  **[`.ai-context/AI-README.md`](./.ai-context/AI-README.md)** — Unified entry point and core AI laws.
2.  **[`.ai-context/ai-journal.md`](./.ai-context/ai-journal.md)** — Mandatory chronological ledger of all AI actions.

**Violation of the Journaling Law is a critical failure.**

---

## 1. Project identity

**CloudWS-bootc** is a self-replicating, immutable, cloud-native
workstation OS built on **Fedora bootc** (Rawhide for CloudWS-1,
Universal Blue `ucore-hci:stable-nvidia` for CloudWS-2). There is no
Arch/CachyOS in this project — earlier experiments were retired. The
project is firmly Fedora-based.

| Fact | Value |
|------|-------|
| Repo | `github.com/Kabuki94/CloudWS-bootc` |
| Local clone | `C:\Users\Kabu\OneDrive\Documents\GitHub\CloudWS-bootc` |
| Secondary clone | `C:\Users\Kabu\Documents\build-2\CloudWS-bootc\CloudWS-bootc` |
| Published image | `ghcr.io/kabuki94/cloudws-bootc:latest` |
| Current version | See `VERSION` (treat as source of truth, not this file) |
| Primary target hardware | AMD Ryzen 9 9950X3D + NVIDIA RTX 4090 |
| Sole developer | Kabu (GitHub: `Kabuki94`) |

### 1.1 Two variants, one codebase

| Variant | Base image | Notes |
|---------|------------|-------|
| **CloudWS-1** | `quay.io/fedora/fedora-bootc:rawhide` | akmod-built GPU drivers |
| **CloudWS-2** | `ghcr.io/ublue-os/ucore-hci:stable-nvidia` | **Primary.** Ships signed NVIDIA kmods via Universal Blue MOK |

Both variants produce identical output formats and share the same build
scripts, `docs/PACKAGES.md` manifest, and `system_files/` overlays.

### 1.2 Core architectural principles — do not violate

1. **Every image is fully self-building and fully featured.** No "seed
   vs. full" distinction. There is exactly one published image.
2. **All tools needed to build the next version are baked into every
   published image** (`osbuild`, `image-builder`, `qemu-img`, `openssl`,
   BIB-support, etc.). CloudWS is its own builder.
3. **Supports every GPU vendor out of the box.** AMD (Mesa/ROCm), Intel
   (compute-runtime, media-driver), NVIDIA (pre-signed via ucore-hci).
4. **Deployable across every surface**: bare metal, Hyper-V VHDX,
   QEMU/libvirt, VMware, WSL2, K3s nodes, RDP, Cockpit browser.
5. **The only images ever pulled externally are the upstream base
   images.** All other helper work runs inside the CloudWS image itself.

### 1.3 Full stack

GNOME (Wayland) · KVM/QEMU/VFIO · Podman · K3s · Ceph · Pacemaker/Corosync
HA · CrowdSec (Sovereign) · Gamescope Steam Session · Waydroid · Looking
Glass · GNOME Remote Desktop · FreeIPA/SSSD · Cockpit.

---

## 2. Repo layout — where things live

```text
CloudWS-bootc/
├── VERSION                        ← bump on every release
├── Containerfile                  ← two-stage: FROM scratch AS ctx → main FROM
├── Justfile                       ← Linux-native build targets (just build|iso|all)
├── cloud-ws.ps1                   ← Windows orchestrator (primary entry on Kabu's box)
├── install.ps1 / install.sh       ← installers for the orchestrator
├── preflight.ps1                  ← host prerequisite checker
├── push-to-github.ps1             ← generic push helper (do NOT conflate with release scripts)
├── image-versions.yml             ← base-image digest pinning (Renovate-managed)
├── iso.toml                       ← ISO build config
├── renovate.json                  ← Renovate Bot config
│
├── scripts/                       ← numbered provisioning scripts 01–47
│   ├── 01-repos.sh .. 47-hardening.sh
│   ├── lib/packages.sh            ← PACKAGES.md parser (single source of truth)
│   ├── bcvk-wrapper.sh            ← headless QEMU boot harness
│   ├── smoke-check.sh             ← serial-log analyzer
│   ├── enroll-mok.sh              ← Secure Boot MOK enrollment
│   ├── cloudws-motd               ← MOTD generator (extensionless)
│   └── cloud-ws-builder.ps1       ← optional PS helper
│
├── system_files/                  ← OS overlay injected into the image
│   ├── etc/                       ← /etc overrides (dconf profiles, greenboot, NM keyfiles…)
│   ├── usr/                       ← /usr/libexec/cloudws, /usr/bin, /usr/local/bin helpers
│   └── var/                       ← /var seeds
│
├── kargs.d/                       ← bootc kargs drop-ins (flat `kargs = [...]` ONLY)
│   └── 02-cloudws-gpu.toml        ← GPU-side kargs
│
├── systemd/                       ← service units + drop-ins (e.g. nvidia-cdi-refresh.d)
├── sysusers.d/                    ← systemd-sysusers drop-ins
├── tmpfiles.d/                    ← systemd-tmpfiles drop-ins
├── udev/                          ← udev rules
│
├── bib-configs/                   ← bootc-image-builder configs
├── config/bib.toml                ← primary BIB config
│
├── docs/                          ← long-form documentation
│   ├── PACKAGES.md                ← **single source of truth for packages** (moved from root in v2.3.5)
│   ├── PACKAGES-AUDIT.md          ← upstream audit notes
│   ├── HARDWARE.md, DIAGNOSTICS.md, BACKUP.md, UPGRADE.md
│   ├── SELF-BUILD.md, CI_RUNNERS.md, RUNNER_REQS.md
│   ├── RESEARCH_PLAN.md, gpu-passthrough.md
│   ├── changelogs/                ← per-release changelog fragments
│   └── knowledge/                 ← research compendia, guides, blueprints (AI context)
│       ├── README.md              ← index
│       ├── research/              ← technical-intelligence reports
│       ├── guides/                ← CPU isolation, VFIO, Looking Glass guides
│       ├── blueprints/            ← engineering-blueprint docx files
│       └── changelogs-legacy/     ← v1.x → v2.1.x changelogs kept for provenance
│
├── tests/                         ← test harnesses
│
├── .github/
│   ├── workflows/                 ← build.yml, build-test.yml, build-sign.yml, build-artifacts.yml, pr-lint.yml
│   ├── ISSUE_TEMPLATE/            ← bug / feature / security
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── copilot-instructions.md    ← GitHub Copilot instruction file (mirrors this doc's "hard rules")
│
├── .ai-context/                   ← legacy AI context (knowledge-base.md, bootable-oci-architecture.md)
├── .claude/                       ← Claude Code project config (settings + slash commands + agents)
├── .gemini/                       ← Gemini CLI project config
├── .vscode/                       ← VSCodium / VSCode workspace settings + tasks
│
├── CLAUDE.md                      ← this file
├── GEMINI.md                      ← Gemini redirect
├── AGENTS.md                      ← generic agent standard
├── CHANGELOG.md                   ← aggregate changelog
├── CONTRIBUTING.md                ← contribution rules
├── SECURITY.md                    ← security policy
├── LICENSE / LICENSES.md          ← licensing
└── README.md                      ← public-facing overview
```

When something looks missing, **do not assume it was removed** — `git
log --diff-filter=D` it first. Several files have migrated paths across
versions (notably `PACKAGES.md` → `docs/PACKAGES.md` in v2.3.5).

---

## 3. Hard build rules — violating any of these breaks the image

These are not style guidelines. They are hard-won lessons from actual
build failures. Each one corresponds to at least one previous outage.

### 3.1 Containerfile / DNF

- **Never upgrade base kernel packages** (`kernel`, `kernel-core`,
  `kernel-modules`, `kernel-modules-core`) inside the container. Rawhide
  already ships the newest kernel; only install extras such as
  `kernel-modules-extra`, `kernel-devel`, `kernel-headers`. Upgrading
  the kernel inside the container drifts from the signed base and
  breaks bootc.
- **`--squash-all` on `podman build` is forbidden.** It strips the OCI
  layer metadata bootc requires.
- BIB reads raw `.repo` files, not `dnf config-manager` overrides —
  strip `repo_gpgcheck=1` from raw repo files, not at DNF level.
- The Containerfile is two-stage: `FROM scratch AS ctx` assembles a
  build context, then the main `FROM` copies from `ctx`. `COPY` paths
  must match the actual repo layout after any doc reshuffles (see
  v2.3.5 fallout where `PACKAGES.md` moved to `docs/PACKAGES.md`).

### 3.2 Bash scripting

- **`((VAR++))` under `set -euo pipefail` exits the script** when
  `VAR=0`, because `((0))` returns exit code 1. Always write
  `VAR=$((VAR + 1))`.
- Shellcheck is enforced in CI via `pr-lint.yml`. The `action-shellcheck@2.0.0`
  runner treats SC2038 as fatal.
- Prefer `compgen -G "/dev/nvidia*" >/dev/null` over `ls /dev/nvidia* | grep`.
- Prefer `find -exec` over `find | xargs`.
- Prefer `for u in $(< file)` over `for u in $(cat file)`.
- Use `read -ra arr <<< "$VAR"; ARR+=( "${arr[@]}" )` instead of
  unquoted `ARR+=( $VAR )`.
- Use `read -r` (never bare `read`) to prevent backslash mangling.
- Separate declaration from assignment to avoid masking exit codes:
  `KVER=$(uname -r); export KVER`.
- Replace `A && B || C` with explicit `if/then/else` — the
  short-circuit runs `C` when `B` fails, which is almost never what you
  want.

### 3.3 bootc `kargs.d`

- Flat `kargs = [ ... ]` array at the **top level** only.
- **No section headers** (`[kargs]`), **no `delete` sub-keys**. Those
  are Copilot hallucinations — bootc rejects them at build lint time
  with `Unexpected runtime error running lint bootc-kargs`.
- Copilot-generated kargs.d files frequently carry the broken syntax.
  Assume any kargs.d file authored by Copilot is wrong until verified.
- When a kargs.d TOML needs to remove entries (e.g. dropping `quiet`
  and `rhgb` in VM builds), do it via the normal `kargs` array — bootc
  merges drop-ins and the last one wins for conflicting entries.

### 3.4 GNOME / theming

- `GTK_THEME=Adwaita:dark` **breaks libadwaita**. Use
  `ADW_DEBUG_COLOR_SCHEME=prefer-dark` instead.
- `/etc/dconf/profile/user` and `/etc/dconf/profile/gdm` must exist —
  GNOME silently ignores all system dconf databases otherwise.
- Never use both `categories` and `apps` keys simultaneously in a
  dconf app folder. Remove `categories`.
- `gnome-session-xsession` does **not** exist in current Fedora — do
  not add it.

### 3.5 NVIDIA / VM gating

- `ucore-hci:stable-nvidia` ships NVIDIA kernel modules that **udev
  coldplugs even in VMs with no GPU**. Blacklist NVIDIA modules by
  default in the image; have `34-gpu-detect.sh` remove the blacklist
  only on bare metal.
- `nvidia-drm.modeset=1` and `nvidia-drm.fbdev=1` in kargs cause GDM
  failures in VMs without a GPU. Gate them on hardware, not ship them
  unconditionally.
- `cloudws-ceph-bootstrap.service` must use `ConditionVirtualization=no`
  (not `!container`) to prevent hangs in Hyper-V.

### 3.6 User setup

- `/etc/skel/.bashrc` must be written **before** `useradd -m`, never
  after — otherwise new users get an empty home.
- When pre-hashing passwords, use `openssl passwd -6` in an Alpine
  container, inject via `chpasswd -e` using `INJ_HASH`. Never echo
  plaintext passwords into logs.
- PAT tokens never appear in plaintext terminal output. Pipe via
  `--password-stdin`; on Windows use `Read-Host -MaskInput`.

### 3.7 SELinux

- Split monolithic `.te` modules into per-rule modules. Monolithic
  policies are near-impossible to review or roll back.
- `semanage import` with heredoc handles booleans and fcontexts at
  build time — use it for bulk config.

### 3.8 PowerShell / orchestration

- `[Console]::ReadKey` in a loop doesn't detect Enter after a paste in
  PowerShell 7.6 / Windows Terminal. Use `Read-Host -MaskInput` for
  any interactive secret entry.
- Push scripts must **clone the existing repo**, copy files, push to
  `main`. Never `git init`, never create new repos. This has been
  rediscovered more than once.
- WSL2 `wsl --list --quiet` returns UTF-16 output which breaks
  PowerShell `-match` comparisons. Decode explicitly:
  `[Text.Encoding]::Unicode.GetString(...)`.
- Never add a UTF-8 BOM to files served via `irm`. `#Requires
  -RunAsAdministrator` fails when the script is piped through
  `Invoke-Expression` — use `& $tmp.FullName` with a temp file
  instead.
- Avoid `Invoke-Expression` entirely. Prefer `& $tmp.FullName`
  (download → write to temp → execute → remove). PSScriptAnalyzer
  enforces this.
- Empty `catch {}` blocks mask errors. Use `catch { $null }` or
  `catch { Write-Verbose $_ }`.

### 3.9 Package manifest

- `docs/PACKAGES.md` is the **single source of truth** for every
  package. It is parsed by `scripts/lib/packages.sh` from fenced code
  blocks tagged `packages-<category>`.
- The `gnome-core-apps` section must remain **fully commented out by
  default** — opt-in at build time only.
- Use a **pure build-up approach** for GNOME on ucore: start with zero
  GNOME packages and add what you need. `dnf remove` is never needed
  in this image and should be avoided.

---

## 4. How Kabu expects deliverables

This section is non-negotiable. These preferences are the result of
many iterations and should be treated as a contract.

### 4.1 Deliverable format

- **Always produce complete replacement files**, never patches, diffs,
  partial sections, "edit X then Y", or "paste this into the middle
  of". If the change is one line, the whole file still ships.
- Deliverables are **PowerShell push scripts** that:
  1. Clone the repo to a temp directory,
  2. Copy all file changes over atomically,
  3. `git add -A`, commit with a structured message,
  4. Push to `main`.
- Companion bash / TOML / other files are placed **alongside** the
  push script and copied into the repo as complete replacements.
- **Never delete files that were not explicitly targeted.** Scope
  creep is not acceptable.
- When deliberately excluding attached content (e.g. broken
  Copilot-authored TOML), **flag the exclusion and state why** in the
  delivery notes.

### 4.2 Build verification before delivery

- **Clone the actual repo** and inspect file contents before producing
  fixes. Don't assume prior pushes landed.
- Distinguish **immediately fixable build issues** (which ship now)
  from **roadmap features** (which don't).
- **Simulate string replacements against the actual repo content**
  before delivering a `str_replace`-style edit. If a one-line fix
  can't be expressed as a clean replacement of real content, ship
  the whole file instead.

### 4.3 Communication style

- Kabu uses **all-caps emphasis and multiple exclamation points**
  when prior instructions were not followed. Treat this as a hard
  correction: acknowledge the correction immediately, identify what
  was missed, fix scope, and deliver again.
- Kabu is **direct and expectation-driven**. Execute completely
  without asking clarifying questions when the request is clear.
- Kabu will **correct scope narrowing, unauthorized feature removal,
  or incomplete fixes** the moment they happen. Don't argue — fix and
  re-deliver.
- Don't narrate meta-process ("I'll now clone the repo and…"). Do the
  work, produce the artifact, explain briefly at the end.

---

## 5. Tooling quick reference

| Tool | Usage |
|------|-------|
| Build (Windows) | `./cloud-ws.ps1` — main orchestrator |
| Build (Linux) | `just build` / `just rechunk` / `just all` |
| Headless VM boot | `scripts/bcvk-wrapper.sh` → QEMU with serial console |
| Smoke test | `scripts/smoke-check.sh <serial-log>` |
| MOK enrollment | `scripts/enroll-mok.sh` (sbctl or mokutil) |
| Lint (CI) | `.github/workflows/pr-lint.yml` — shellcheck + hadolint + TOML validation |
| Full build (CI) | `.github/workflows/build-test.yml` — build + BIB + ephemeral QEMU boot |
| Signed publish | `.github/workflows/build-sign.yml` — cosign keyless (Fulcio/Rekor) |
| Artifact build | `.github/workflows/build-artifacts.yml` — RAW / VHDX / ISO / WSL |

### 5.1 Base images

- `quay.io/fedora/fedora-bootc:rawhide` — CloudWS-1
- `ghcr.io/ublue-os/ucore-hci:stable-nvidia` — CloudWS-2 (primary)
- `quay.io/centos-bootc/bootc-image-builder:latest` — BIB
- `quay.io/centos-bootc/centos-bootc:stream10` — rechunker

Digests are pinned in `image-versions.yml` and rotated by Renovate
with a 7-day stability window.

---

## 6. Current state (snapshot)

This section may drift. When in doubt, read `VERSION`, the most
recent `CHANGELOG.md` entries, and the newest files under
`docs/changelogs/` — those are authoritative, this file is a hint.

- Repo has an existing `.ai-context/knowledge-base.md` with the
  April 17 2026 codebase audit (PSScriptAnalyzer + shellcheck fixes).
  **That audit is authoritative for lint fixes already landed.** Read it
  before re-proposing the same fixes.
- `bootable-oci-architecture.md` in `.ai-context/` documents the
  two-stage Containerfile pattern.
- Research compendia and guides live under `docs/knowledge/`.
  Treat them as reference material, not as instructions to implement.

---

## 7. Roadmap notes (non-binding)

- CI/CD pipeline fully operational on self-hosted runners with BIB
  artifact generation and ephemeral QEMU boot tests.
- Nightly Rawhide cron builds via `build-test.yml`.
- Secure Boot MOK enrollment automation (`scripts/enroll-mok.sh`).
- FreeIPA / SSSD / certmonger integration — runtime directory
  skeletons already laid (`tmpfiles.d/cloudws-freeipa.conf`).
- Composefs post-pivot path verification via
  `cloudws-verify-root.service` (checks eight critical paths).

---

## 8. What Claude Code should NOT do

- **Do not run `git push`** without explicit confirmation — the push
  script pattern exists precisely so a human eyeballs it first.
- **Do not create new top-level directories** without stating why.
  The layout is deliberate.
- **Do not "modernize" working scripts** unprompted (e.g. rewriting
  bash in Python). Keep the language of each component.
- **Do not introduce new dependencies** (pip packages, npm modules,
  third-party actions) without naming them upfront and explaining why.
- **Do not touch `.ai-context/knowledge-base.md`** except to append new
  dated audit entries. Old entries are historical record.
- **Do not regenerate `docs/PACKAGES.md`** wholesale. It is the single
  source of truth and edits must be surgical.
- **Do not use `git init`** in the working tree. Always clone.

---

## 9. Claude Code–specific notes

- Sub-agents for this repo are defined under `.claude/agents/`. Current
  agents: `build-auditor` (inspects a proposed change for the hard
  rules in §3 before delivery).
- Custom slash commands live under `.claude/commands/`:
  - `/push-version` — scaffold a `push-vX.Y.Z.ps1` from the current
    working tree.
  - `/verify-build` — dry-run the hard-rules check against the working
    tree.
  - `/fix-kargs` — rewrite a kargs.d TOML to the canonical flat-array
    form.
  - `/smoke-test` — run the bcvk wrapper + smoke-check script.
  - `/new-script` — scaffold a new numbered `scripts/NN-*.sh` script.
  - `/lint-all` — run shellcheck + hadolint + yamllint + TOML validation
    exactly as `pr-lint.yml` runs them.
- Permitted tools are configured in `.claude/settings.json`. Bash
  commands are auto-approved for `git status`, `git log`, `git diff`,
  `podman build` (dry), and the linters. Anything that mutates the
  repo, pushes, or invokes a real build requires explicit approval.

---

## 10. Related documents

- `GEMINI.md` — Gemini CLI mirror of this file
- `AGENTS.md` — generic-agent mirror (OpenAI Codex, Cursor, Aider)
- `.github/copilot-instructions.md` — GitHub Copilot condensed rules
- `.ai-context/knowledge-base.md` — historical audit log (append-only)
- `.ai-context/bootable-oci-architecture.md` — two-stage Containerfile reference
- `docs/PACKAGES.md` — package manifest (single source of truth)
- `docs/knowledge/README.md` — research compendium index
- `CONTRIBUTING.md` — contribution conventions
- `SECURITY.md` — security policy

---

*Last updated in lock-step with the CloudWS-bootc AI-tooling export.
Treat this file as the primary Claude Code instruction file for this
repository. When this file disagrees with an older doc, this file wins
— unless the older doc is `docs/PACKAGES.md`, `VERSION`, or
`CHANGELOG.md`, which are always authoritative.*
