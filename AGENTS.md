# AGENTS.md — OpenAI Codex CLI / ChatGPT Agents (MiOS)

> Read by OpenAI Codex CLI (`codex`), ChatGPT with Code Interpreter, and OpenAI platform agents.
> Full architecture laws live in `AI.md` — read it for the complete picture.

## Project

MiOS is a **bootc-based, self-building, immutable workstation OS** on Fedora Rawhide.
One OCI image covers all roles: desktop, k3s/HA, GPU passthrough (VFIO), WSL2.
Published at `ghcr.io/kabuki94/mios:latest`. Updates: `sudo bootc upgrade`.

## Build & Test

```bash
just build                                # Build OCI image
just lint                                 # bootc container lint
./tests/smoke-test.sh localhost/mios:dev  # Validate (run after build)
.\mios-build-local.ps1                   # Windows build
```

## Architecture

- **Containerfile** has two stages: `ctx` (assembles build context) and `main` (runs overlay + numbered scripts)
- **Packages:** all declared in `docs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` in fenced blocks
  ` ```packages-<category> ` — install via `install_packages <category>` from `scripts/lib/packages.sh`
- **System files:** `system_files/` mirrors the root — all system config lives here, nowhere else

## Critical Rules (violating these breaks the build)

### kargs.d TOML
```toml
kargs = ["key=value", "flag"]   # Only valid format
```
Never: `[kargs]` header, `delete =`, `kargs.append =`, `[[kargs]]`

### Bash
- `VAR=$((VAR + 1))` — never `((VAR++))` (kills script under `set -e` when result=0)
- Never `dnf install kernel` inside the container
- Never `--squash-all` on `podman build`

### Immutable OS rules
- Never `mkdir /var/...` in scripts — use `tmpfiles.d` declarations
- Never `semodule -i` at build time — stage modules, load via service
- All system config goes in `/usr/lib/`, not `/etc/`

### Deliverable format
Complete replacement files only. Use `push-to-github.ps1` to push. Never `git init`.

## Memory

Append episodic actions to `.claude/memories/journal.md` with timestamp + `[AI: Codex CLI]`.
Semantic memory: `.claude/memory/`. Scratchpad: `.claude/shared-tmp/`.
