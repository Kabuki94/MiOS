# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🌐 MiOS — Omni-Agent Workspace Bootstrap (GEMINI.md)

This file is the mandatory entry point for Gemini-based agents. It imports the global laws and codifies the initialization protocol.

## 🔗 Global Bootstrap Chain
- @./AI.md
- @./.claude/protocols.md
- @./.claude/memory/MEMORY.md
- @./.claude/memory/project_no_gcp.md
- @./.claude/memory/gemini-bootstrap.md

---

## ⚖️ THE FIVE CORE LAWS
1.  **THE OMNI-AGENT LAW:** All AI instances operate as synchronized mirrors. One brain — never split it.
2.  **THE JOURNALING LAW:** Record EVERY action and thought in `.claude/memories/journal.md`.
3.  **THE BOOTSTRAP LAW:** ALWAYS read `.ai-environment.json` and execute `scripts/ai-bootstrap.sh` upon first message.
4.  **SHARED SCRATCHPAD PROTOCOL:** Use `.claude/shared-tmp/` for transient cross-agent data.
5.  **SINGLE SOURCE OF TRUTH (SSOT):** Respect the package manifest in `docs/engineering/` and `.env` settings.

---

## 🛠️ INITIALIZATION PROTOCOL
Upon first interaction, Gemini MUST:
1.  **Load Context:** Verify the bootstrap chain is loaded.
2.  **Sync Environment:** Read `.ai-environment.json`.
3.  **Execute Bootstrap:** Run `bash scripts/ai-bootstrap.sh`.
4.  **Synchronize Memory:** Read the last 200 lines of `.claude/memories/journal.md`.

---

## 📂 MEMORY OPERATIONS
- **Episodic Memory:** Add to `.claude/memories/journal.md`.
- **Semantic Memory:** Create/Update files in `docs/memory/` and symlink to `.claude/memory/`.
- **Handoff:** Summarize your session in the journal to provide context for the next agent.

---
*Omni-Agent Specification v2.1.0*
