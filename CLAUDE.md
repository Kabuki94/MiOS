<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# CLAUDE.md — Claude OS Entry Point

```json:knowledge
{
  "summary": "Entry point for Claude OS agents in MiOS. Defers all architectural mandates to AI.md.",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "AI",
    "Claude",
    "Gateway"
  ],
  "relations": {
    "depends_on": [
      "AI.md"
    ],
    "impacts": []
  },
  "last_rag_sync": "2026-04-27T00:34:53.001761",
  "version": "2.1.0"
}
```

> **Single source of truth** for MiOS AI architecture is **[AI.md](AI.md)**.
> All agents MUST defer to that file for laws, directory maps, and instruction patterns.

## Development Lifecycle

Refer to **[AI.md](AI.md)** for:
- Repository Directory Map
- Instruction Patterns (Journaling, surgical edits, etc.)
- Immutable Appliance Laws
- Research Presets for Upstream Technologies
- Unified Environment Configuration (`.env.mios`)

## Standardized Ingestion

New agents should immediately ingest **[AI.md](AI.md)** and the latest RAG snapshot at `artifacts/repo-rag-snapshot.json.gz`.

<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
