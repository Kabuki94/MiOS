<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# AI.md — MiOS Universal Agent Hub
```json:knowledge
{
  "summary": "> **Single source of truth** for every AI agent, LLM, copilot, and API operating in this repository.",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "root"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```

> **Single source of truth** for every AI agent, LLM, copilot, and API operating in this repository.
> All provider entry files (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`, `.cursorrules`, `.windsurfrules`,
> `.clinerules`, `.github/copilot-instructions.md`) defer to this file for architecture laws and conventions.

## Project

MiOS is a **bootc-based, self-building, immutable workstation OS** on Fedora Rawhide.
One OCI image covers all hardware roles: desktop, k3s/HA, GPU passthrough (VFIO), WSL2.
Published at `ghcr.io/kabuki94/mios:latest`. Deployed systems update atomically via `sudo bootc upgrade`.
Sole proprietor: **Kabu.ki**. Target: AMD Ryzen 9 9950X3D + NVIDIA RTX 4090, hardware-agnostic by design.

## Build & Test

```bash
just build                                 # Build OCI image → localhost/mios:latest
just lint                                  # bootc container lint
just rechunk                               # Rechunk for Day-2 delta efficiency
just raw / just iso / just vhd / just wsl  # Disk image generation via BIB
just all                                   # Full pipeline: build → rechunk → images → push
just clean                                 # Remove output/ and local images
./tests/smoke-test.sh localhost/mios:dev   # Validate image (run after just build)
.\mios-build-local.ps1                    # Windows: 5-phase Podman Desktop build
```

## Architecture

### Build pipeline

The `Containerfile` has two stages:

1. **`ctx` stage** — `scratch` image assembling: `scripts/`, `system_files/`,
   `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` (as `/ctx/PACKAGES.md`), `VERSION`, `bib-configs/`, `tools/`
2. **`main` stage** — applies `system_files/` overlay via `08-system-files-overlay.sh`, then runs
   `scripts/build.sh` (all `scripts/[0-9][0-9]-*.sh` in order)

Scripts `18-`, `19-`, `20-`, `21-`, `22-`, `23-`, `25-`, `26-`, `37-` are called explicitly by the
Containerfile *after* `build.sh` completes — do not also run them inside `build.sh`.

### Package system

All packages declared in `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` in fenced blocks:

````
```packages-<category>
package-name
another-package
```
````

Scripts install via `install_packages <category>` from `scripts/lib/packages.sh`.
Never add packages outside this system.

### System files overlay

`system_files/` mirrors the root filesystem. **All system config lives here** — no top-level overlay
directories. Files are applied by `scripts/08-system-files-overlay.sh`, which handles the
`/usr/local → /var/usrlocal` symlink present on ucore/FCOS bases.

## Immutable Appliance Laws

These are absolute. Any violation causes state drift, CI failure, or broken deployments.

1. **USR-OVER-ETC** — Never write static system config to `/etc/` at build time. Use `/usr/lib/<component>.d/`. `/etc/` is for user/admin overrides only.
2. **NO-MKDIR-IN-VAR** — Never `mkdir /var/...` in build scripts. Declare all `/var` dirs via `tmpfiles.d` (`d` or `C` directives) so `bootc upgrade` creates them on existing deployments.
3. **MANAGED-SELINUX** — Never `semodule -i` at build time. Stage `.te` modules in `/usr/share/selinux/packages/` and load via `mios-selinux-init.service` asynchronously.
4. **BOUND-IMAGES** — All primary Quadlet sidecar containers must be symlinked into `/usr/lib/bootc/bound-images.d/` for atomic updates via `bootc upgrade`.
5. **BOOT-SHIELDING** — All `dnf` operations must use `excludepkgs="shim-*,kernel*"` to prevent bootloader regressions.

## Hard Rules (build-breaking violations)

### kargs.d TOML — most common AI mistake

```toml
# Only valid format:
kargs = ["key=value", "flag"]
```

Never: `[kargs]` section header · `delete =` · `delete_kargs =` · `kargs.append =` · `[[kargs]]`

### Bash

- `set -euo pipefail` in all scripts; `build.sh` uses `set -uo pipefail` for per-script error tolerance
- `VAR=$((VAR + 1))` always — never `((VAR++))` (exits 1 when result=0, kills script under `set -e`)
- Never `dnf install kernel` or `dnf upgrade kernel` inside the container
- Never `--squash-all` on `podman build` (strips OCI metadata bootc requires)
- Quote all variables; use `read -r`; separate declaration from assignment for command substitutions

### GNOME / theming

- Never `GTK_THEME=Adwaita:dark` → use `ADW_DEBUG_COLOR_SCHEME=prefer-dark`
- `/etc/dconf/profile/user` and `/etc/dconf/profile/gdm` must exist
- Never put both `categories=` and `apps=` in a dconf app folder at the same time
- `xorgxrdp-glamor` only (`xorgxrdp` conflicts with it)
- `gnome-session-xsession` does not exist in Fedora — do not suggest it

### NVIDIA / VM gating

- NVIDIA blacklisted by default; unblacklisted only on bare metal via `34-gpu-detect.sh`
- Never ship `nvidia-drm.modeset=1` or `nvidia-drm.fbdev=1` unconditionally in kargs

### PowerShell

- Never `Invoke-Expression` on downloaded content — write to temp file + `& $tmp.FullName` + remove
- Never empty `catch {}`
- Secrets via `Read-Host -MaskInput` or `[SecureString]`
- Push scripts must clone the existing repo — never `git init`

### Packages / Containerfile

- `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` is the package SSOT — never regenerate wholesale
- The `gnome-core-apps` block must remain commented out
- COPY path for packages: `COPY docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md /ctx/PACKAGES.md`

### Disk image generation

- ISO builds use `iso.toml` exclusively — never mount both `iso.toml` and `bib.toml` at the same time (BIB crashes: "found config.json and also config.toml")

## Shared Memory System

| Path | Purpose |
|---|---|
| `.claude/memories/journal.md` | Episodic memory — timestamped log of all AI actions |
| `.claude/memory/` | Semantic memory — named `.md` files per topic |
| `.claude/shared-tmp/` | Scratchpad — transient cross-agent data |

All agents append to `journal.md` with timestamp + agent identity tag:

```
[2026-04-26T14:00:00Z] [AI: Claude Code] Analyzed scripts/35-gpu-passthrough.sh — found...
```

## Machine-readable Context

| File | Purpose |
|---|---|
| `.ai-environment.json` | Workspace metadata (fonts, extensions, apps, version) |
| `ai-context.json` | Index of all docs, memories, scripts, manifests |
| `docs/audit/MiOS-Omni-Todo.html` | Unified HTML To-Do list for Users and Agents (append `<li>` before `<!-- TASK_END -->`) |
| `scripts/ai-bootstrap.sh` | Regenerates manifests; initializes sub-project envs |

## Protected Files

Do not modify without explicit authorization from Kabu.ki:

- `VERSION` and `CHANGELOG.md` — managed only via `push-to-github.ps1`
- `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` — surgical edits only
- `.github/workflows/build-sign.yml` and `.github/workflows/build-artifacts.yml`
- `docs/memory/**` — AI semantic memory store

## Deliverable Contract

Complete replacement files only — no patches, no diffs, no "paste this into X". One push script:
`push-to-github.ps1` (clone → copy → commit → push). Never `git init`. Never push without human review.

## Provider Index

| Agent / Tool | Entry file | Mechanism |
|---|---|---|
| Claude Code (Anthropic) | `CLAUDE.md` | Auto-loaded at session start |
| Gemini CLI (Google) | `GEMINI.md` | `@./` import chain |
| GitHub Copilot | `.github/copilot-instructions.md` | System prompt injection |
| Cursor | `.cursorrules` | Context injection |
| Windsurf (Codeium) | `.windsurfrules` | Context injection |
| Cline (VS Code) | `.clinerules` | Context injection |
| OpenAI Codex CLI | `AGENTS.md` | Auto-loaded at session start |
| Aider | `.aider.conf.yml` + `AI.md` | Config + read |
| Web LLMs / scrapers | `llms.txt` | Structured index |
| MCP / programmatic | `ai-context.json` | JSON manifest |
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
