<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# AGENT.md — Agent CLI Entry Point

```json:knowledge
{
  "summary": "Entry point for Agent CLI. Initializes context via import chain.",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "AI",
    "Agent",
    "Gateway"
  ],
  "relations": {
    "depends_on": [
      "INDEX.md"
    ],
    "impacts": []
  },
  "last_rag_sync": "2026-04-27T03:46:51.769936",
  "version": "0.1.1"
}
```

> **MANDATORY ENTRY POINT:** This repository is managed via the **MiOS Agent Workspace**. 
> All agents share identical context, memories, and workspace.

## 🚀 Context Initialization Chain

@./INDEX.md
@./.ai/foundation/protocols.md
@./.ai/foundation/memory/MEMORY.md
@./.ai/foundation/memory/project_no_gcp.md
@./.ai/foundation/memory/agent-bootstrap.md

## ⚖️ THE CORE LAWS (Omni-Agent)

1. **THE COGNITIVE SYNC LAW:** All agents are synchronized. They read from and write to the same memory files (`JOURNAL.md`) and share the same cognitive state. There is one brain — never split it.
2. **THE JOURNALING LAW:** Every surgical change, architectural decision, learning, discovery, or thought **MUST** be recorded in the shared `JOURNAL.md` at the end of every session turn with timestamp + agent tag (e.g., `[AI: Agent CLI]`).
3. **SHARED SCRATCHPAD PROTOCOL:** Use `.ai/foundation/shared-tmp/` as the universal scratchpad for transient data, inter-agent communication, and cross-session "thoughts." 
4. **SINGLE SOURCE OF TRUTH (SSOT):**
    - **Packages:** `specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` is the only manifest.
    - **Environment:** `.env` and `.env.mios` track the baseline.
5. **USR-OVER-ETC (BOOTC IMMUTABILITY):** Align with upstream `bootc`. System configurations go in `usr/lib/`. `/etc` is reserved for user overrides only.

---
### ⚖️ Legal & Source Reference
- **Copyright:** (c) 2026 Kabu.ki
- **Status:** Personal Property / Private Infrastructure
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Documentation:** [MiOS Navigation Hub](https://github.com/Kabuki94/mios/blob/main/docs/Home.md)
- **Artifact Hub:** [ai-context.json](https://github.com/Kabuki94/mios/blob/main/ai-context.json)
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
