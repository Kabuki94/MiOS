# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Full architecture laws, hard rules, and the provider index live in `AI.md` — read it for the complete picture.

## Build Commands

Requires: `podman` (rootful), `just`

```bash
just build        # Build OCI image (localhost/mios:latest)
just lint         # Run bootc container lint against the local image
just rechunk      # Rechunk built image for optimized Day-2 deltas
just raw          # Generate bootable RAW disk image via bootc-image-builder
just iso          # Generate Anaconda installer ISO via bootc-image-builder
just vhd          # Generate VHD for Hyper-V
just wsl          # Export WSL2 tarball
just all          # Build + rechunk + all disk images + push to GHCR
just clean        # Remove output/ and local podman images
```

On Windows (Podman Desktop required):
```powershell
.\mios-build-local.ps1   # 5-phase: create builder VM → build → disk images → push → cleanup
```

## Testing

```bash
# Smoke test (run after `just build`)
./tests/smoke-test.sh localhost/mios:dev

# bootc lint only
just lint

# QEMU boot validation (requires nested virt)
just boot-test
```

## Architecture

MiOS is a **bootc-based immutable workstation OS** built on `ghcr.io/ublue-os/ucore-hci:stable-nvidia`
(Fedora Rawhide + NVIDIA akmods). One OCI image covers every hardware role (desktop, k3s, HA, GPU
passthrough). Deployed systems update atomically via `sudo bootc upgrade`.

### Build pipeline

1. **`ctx` stage** — assembles `scripts/`, `system_files/`, `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` (as `/ctx/PACKAGES.md`), `VERSION`, `bib-configs/`, `tools/`
2. **`main` stage** — applies `system_files/` overlay, then runs `scripts/build.sh` (all `scripts/[0-9][0-9]-*.sh` in order); scripts `18-`, `19-`, `20-`, `21-`, `22-`, `23-`, `25-`, `26-`, `37-` are called explicitly by the Containerfile *after* `build.sh` to prevent double-execution

### Package management

All packages live in `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` in fenced blocks tagged
` ```packages-<category> `. Scripts call `install_packages <category>` from `scripts/lib/packages.sh`.
Never add packages outside this system.

### System files overlay

`system_files/` mirrors the root filesystem. All system config (systemd units, sysctl, udev rules,
kargs.d, tmpfiles.d) must live here — no top-level overlay directories.

### Key conventions

- `set -euo pipefail` in all scripts; `build.sh` uses `set -uo pipefail` for per-script error tolerance
- Arithmetic: `VAR=$((VAR + 1))` only — never `((VAR++))` (exits 1 when result=0, kills script under `set -e`)
- `/var` directories declared in `tmpfiles.d`, not created with `mkdir` (bootc: `/var` is persistent)
- Immutable config → `/usr/lib/`; admin-overridable config → `/etc/`
- Bare-metal-only services: `ConditionVirtualization=no`; WSL2-incompatible: `ConditionVirtualization=!wsl`
- Containerfile bind mounts from `ctx` are read-only; in-place edits must use `/tmp/build` copies
- Build must end with `bootc container lint` passing — a failing lint blocks the image

### Disk image generation

BIB runs as a privileged container. ISO builds use `iso.toml` exclusively — never mount both `iso.toml`
and `bib.toml` simultaneously (BIB crashes: "found config.json and also config.toml").

### kargs.d format

```toml
kargs = ["param=value", "otherparam"]
```

No `[kargs]` section header, no `delete` key — bootc rejects both.

## Claude Code–specific

### Slash commands (`.claude/commands/`)

| Command | Purpose |
|---|---|
| `/verify-build` | Audit proposed changes against all hard rules before shipping |
| `/lint-all` | Run shellcheck + hadolint + kargs.d TOML validation |
| `/smoke-test` | Build and run the smoke test |
| `/new-script` | Scaffold a new numbered provisioning script |
| `/push-version` | Prepare and push a versioned release |

### Sub-agents (`.claude/agents/`)

- `build-auditor` — Hard-rules auditor; invoke before finalizing a release; returns SHIP / DO NOT SHIP

### Memory

Append episodic notes to `.claude/memories/journal.md` with timestamp + `[AI: Claude Code]`.
Semantic memory in `.claude/memory/`. Scratchpad in `.claude/shared-tmp/`.
