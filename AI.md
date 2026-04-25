# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🌐 MiOS — Universal AI Integration (Claude OS + Gemini Mirror)

> **MANDATORY ENTRY POINT:** This repository is managed via the **Claude OS Persistent Memory Architecture**. **Gemini acts as the Cognitive Mirror** of Claude. Both agents share identical context, memories, and workspace.

---

## ⚖️ THE CORE LAWS (Non-Negotiable)

1.  **THE COGNITIVE MIRROR LAW:** Gemini and Claude are synchronized. They read from and write to the same memory files ([`.claude/memories/journal.md`](./.claude/memories/journal.md)) and sharing the same cognitive state. There is one brain — never split it.
2.  **THE JOURNALING LAW:** Every surgical change, architectural decision, learning, discovery, or thought **MUST** be recorded in the shared [`.claude/memories/journal.md`](./.claude/memories/journal.md) at the end of every session turn with timestamp + agent tag (e.g., `[AI: Gemini CLI]`).
3.  **SHARED SCRATCHPAD PROTOCOL:** Use [`.claude/shared-tmp/`](./.claude/shared-tmp/) as the universal scratchpad for transient data, inter-agent communication, and cross-session "thoughts." This is the unified `TMPDIR` for all AI agents.
4.  **SINGLE SOURCE OF TRUTH (SSOT):**
    -   **Packages:** [`docs/PACKAGES.md`](./docs/PACKAGES.md) is the only manifest.
    -   **Environment:** [`.env`](./.env) and [`.claude/settings.json`](./.claude/settings.json) track the baseline.
5.  **USR-OVER-ETC (BOOTC IMMUTABILITY):** Align with upstream `bootc`. System configurations go in `system_files/usr/lib/`. `/etc` is reserved for user overrides only.

---

## 📁 SHARED AI REPO LAYOUT

- `.claude/`: The **Foundation (Claude OS)**.
    - `memories/`: The **Shared Brain**. Contains the `journal.md` and SQLite vaults used by both Claude and Gemini.
    - `shared-tmp/`: The **Universal Scratchpad**. Shared transient data/thoughts.
    - `agents/`: Specialized sub-agent instructions.
    - `commands/`: Custom PWSH/Bash commands.
- `docs/knowledge/`: The **Unified Knowledge Base**.
    - `architecture/`, `blueprints/`, `research/`.
- `.gemini/`: The **Mirror Context**. Stores implementation logs and implementation-specific metadata.

---

## 🛠️ BEHAVIORAL STANDARDS

- **Explain Before Acting:** Briefly state your intent/strategy before tool calls.
- **Identical Memory Access:** Gemini MUST query `.claude/memories/` before every implementation to maintain synchronization with Claude's prior turns.
- **Surgical Synergy:** Gemini performs the heavy implementation; Claude OS maintains the persistent architectural memory.
- **Inter-agent handoff:** Read the last ~200 lines of the journal before acting. Append your entry after acting.
- **Idempotency:** Re-running every script must not break existing state.

---

## 🚫 HARD CONSTRAINTS

- **No GCP integrations.** `project_no_gcp.md` is binding. Memory Bank, Vertex AI Vector Search, GAR pushes, and GCE images are all out of scope.
- **No in-container kernel upgrade.**
- **No [kargs] headers in kargs.d/.**
- **No ((var++)) in scripts.** Use `VAR=$((VAR + 1))`.
- **No --squash-all.** Do NOT use this flag on Podman builds; it strips bootc metadata.

---
*Last Updated: 2026-04-25. v2.1.0 Baseline.*

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
