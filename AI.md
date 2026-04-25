# 🌐 CloudWS-bootc — Universal AI Integration (Claude OS + Gemini Shadow)

> **MANDATORY ENTRY POINT:** This repository is managed via the **Claude OS Persistent Memory Architecture**. **Gemini acts as the Shadow Copy** of Claude. Both agents share identical context, memories, and workspace.

---

## ⚖️ THE CORE LAWS (Non-Negotiable)

1.  **THE SHADOW COPY LAW:** Gemini and Claude are synchronized. They read from and write to the same memory files ([`.claude/memories/journal.md`](./.claude/memories/journal.md)) and sharing the same cognitive state.
2.  **SHARED SCRATCHPAD PROTOCOL:** Use [`.claude/shared-tmp/`](./.claude/shared-tmp/) as the universal scratchpad for transient data, inter-agent communication, and cross-session "thoughts." This is the unified `TMPDIR` for all AI agents.
3.  **THE JOURNALING LAW:** Every surgical change, architectural decision, and finding **MUST** be recorded in the shared [`.claude/memories/journal.md`](./.claude/memories/journal.md) at the end of every session turn.
4.  **SINGLE SOURCE OF TRUTH (SSOT):**
    -   **Packages:** [`docs/PACKAGES.md`](./docs/PACKAGES.md) is the only manifest.
    -   **Environment:** [`.env`](./.env) and [`.claude/settings.json`](./.claude/settings.json) track the baseline.
5.  **USR-OVER-ETC (BOOTC IMMUTABILITY):** Align with upstream `bootc`. System configurations go in `system_files/usr/lib/`.

---

## 📁 SHARED AI REPO LAYOUT

- `.claude/`: The **Foundation (Claude OS)**.
    - `memories/`: The **Shared Brain**. Contains the `journal.md` and SQLite vaults used by both Claude and Gemini.
    - `shared-tmp/`: The **Universal Scratchpad**. Shared transient data/thoughts.
    - `agents/`: Specialized sub-agent instructions.
    - `commands/`: Custom PWSH/Bash commands.
- `docs/knowledge/`: The **Unified Knowledge Base**.
    - `architecture/`, `blueprints/`, `research/`.
- `.gemini/`: The **Shadow Context**. Stores implementation logs and implementation-specific metadata.

---

## 🛠️ BEHAVIORAL STANDARDS

- **Explain Before Acting:** Briefly state your intent/strategy before tool calls.
- **Identical Memory Access:** Gemini MUST query `.claude/memories/` before every implementation to maintain synchronization with Claude's prior turns.
- **Surgical Synergy:** Gemini performs the heavy implementation; Claude OS maintains the persistent architectural memory.

---
*Last Updated: 2026-04-25. v1.3.0 Baseline.*
