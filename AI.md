# 🤖 CloudWS-bootc — Unified AI Agent Standards

> **MANDATORY ENTRY POINT:** This is the authoritative, single-source-of-truth for all AI agents (Claude, Gemini, Cursor, Aider, etc.) operating within this repository. **READ THIS IN FULL BEFORE EVERY TURN.**

---

## ⚖️ THE CORE LAWS (Non-Negotiable)

1.  **THE JOURNALING LAW:** Every surgical change, architectural decision, and finding **MUST** be recorded in [`.ai-context/ai-journal.md`](./.ai-context/ai-journal.md) at the end of every session turn.
2.  **SINGLE SOURCE OF TRUTH (SSOT):**
    -   **Packages:** [`docs/PACKAGES.md`](./docs/PACKAGES.md) is the only manifest.
    -   **Environment:** [`.ai-context/AI-ENVIRONMENT.md`](./.ai-context/AI-ENVIRONMENT.md) tracks the baseline.
3.  **SHARED THOUGHTS PROTOCOL:** Use [`.ai-context/shared-tmp/`](./.ai-context/shared-tmp/) as the universal scratchpad for transient data, inter-agent communication, and cross-session "thoughts." This directory is the unified `TMPDIR` for all AI agents.
4.  **USR-OVER-ETC (BOOTC IMMUTABILITY):** Align with upstream `bootc`. System-provided configurations go in `/usr/lib/`. `/etc/` is reserved for local overrides and runtime state.
5.  **REBUILD INTEGRITY:** Never modify or delete files unless they are explicitly targeted for a task.

---

## 🏢 PROJECT IDENTITY & STATE

**CloudWS-bootc** is a self-building, immutable, cloud-native workstation OS built on **Fedora bootc** (Primary: `ucore-hci:stable-nvidia`).

| Component | Status |
|-----------|--------|
| **Baseline** | v1.3.0 (The Standardized Stack) |
| **Hardware** | **Agnostic** (Universal Intel/AMD/NVIDIA/Apple/ARM Support) |
| **Deployment** | Universal (Bare-metal, VM, OCI, WSL2/g, Hyper-V, Podman/Docker, LVM) |
| **Para-virt** | Full (GPU-PV, SR-IOV, VSOCK, virtio-gpu, DDA/DDS) |
| **Compute** | Universal (X3D V-Cache, Intel Hybrid P/E, Multi-NUMA, ARM Neoverse) |
| **Storage** | Agnostic (Workstation Ceph + K3s, NVMe-over-Fabrics, ZFS, Btrfs) |

---

## 📁 REPO LAYOUT (The Map)

- `Containerfile`: Two-stage build (ctx stage → main stage).
- `Justfile`: Linux-native targets (`build`, `ukify`, `iso`, `rechunk`).
- `scripts/`: Numbered provisioning pipeline (`01-repos.sh` through `47-hardening.sh`).
- `system_files/`: Immutable OS overlay (`usr/lib/` preferred for drop-ins).
- `kargs.d/`: Bootc kernel arguments (Flat TOML array ONLY).
- `docs/PACKAGES.md`: The SSOT manifest for all RPMs.
- `tools/`: Diagnostic toolkit and development helpers.

---

## 🛑 HARD BUILD RULES (Violation = Fatal Failure)

### 1. Bootc & Kernel
- **Kernel Gating:** Never upgrade `kernel-core` inside the container. Only add modules/headers.
- **kargs.d Syntax:** Flat `kargs = [...]` array at top level. **NO** `[kargs]` headers. **NO** `delete` keys.
- **No Squash:** Do NOT use `--squash-all` on Podman builds; it strips bootc metadata.

### 2. Scripting & Shell
- **Safe Increment:** Use `VAR=$((VAR + 1))`, never `((VAR++))` under `set -e`.
- **VSOCK RDP:** Use `gnome-remote-desktop` with GDM. xRDP is incompatible with GNOME 50.
- **Hardware Gating:** Blacklist NVIDIA modules by default; only enable via `gpu-detect` on bare metal.

### 3. Deliverables
- **Complete Files:** Ship complete replacement files only. Never partial edits or diffs.
- **Push Scripts:** For Kabu (Maintainer), deliver PowerShell push scripts that clone → copy → push.

---

## 🛠️ BEHAVIORAL STANDARDS FOR AGENTS

- **Explain Before Acting:** Briefly state your intent/strategy before tool calls.
- **Surgical Actions:** Use the `replace` tool for codebase updates.
- **Validation:** Always verify changes with `bootc container lint` or script dry-runs where possible.
- **Acknowledgement:** If corrected in ALL CAPS by Kabu, acknowledge, fix scope, and redeliver.

---

## 📜 RELATED RULES & MACHINE CONFIGS

- [`.ai-rules`](./.ai-rules) — Machine-readable behavioral manifest (TOML).
- [`.ai-context/AI-README.md`](./.ai-context/AI-README.md) — Unified entry point.
- [`.ai-context/knowledge-base.md`](./.ai-context/knowledge-base.md) — Historical audit log.

---
*Last Updated: 2026-04-25. Consolidated from AGENTS.md, CLAUDE.md, and GEMINI.md.*
