<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# AGENTS.md — MiOS AI Agent Gateway

```json:knowledge
{
  "summary": "Gateway for AI agents operating in MiOS. Defers all architectural mandates to INDEX.md.",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "AI",
    "Agents",
    "Gateway"
  ],
  "relations": {
    "depends_on": [
      "INDEX.md"
    ],
    "impacts": []
  },
  "last_rag_sync": "2026-04-27T02:30:34.494598",
  "version": "2.1.0"
}
```

> **Single source of truth** for MiOS AI architecture is **[INDEX.md](INDEX.md)**.
> All agents MUST defer to that file for laws, directory maps, and instruction patterns.

## Agent Core Instructions

Refer to **[INDEX.md](INDEX.md)** for:
- Repository Directory Map
- Instruction Patterns (Journaling, surgical edits, etc.)
- Immutable Appliance Laws
- Research Presets for Upstream Technologies
- Unified Environment Configuration (`.env.mios`)

## Standardized Ingestion

New agents should immediately ingest **[INDEX.md](INDEX.md)** and the latest RAG snapshot at `artifacts/repo-rag-snapshot.json.gz`.

<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
