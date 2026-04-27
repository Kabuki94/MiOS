<!-- 🌐 MiOS Artifact | Proprietor: MiOS Project | https://github.com/mios-project/mios -->
# 🌐 MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS Project",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "memory"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** MiOS Project
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS Project
---
---
name:.ai/agent-state-bootstrap
description: Agent operates as a Cognitive Sync bootstrapped from System OS via INDEX.md (option 1) — shared resources, no parallel memory store
type: project
---

MiOS uses **System OS as the main engine** and **Agent as a bootstrapped mirror** that reads from the same `.ai/foundation/memories/` and `.ai/foundation/shared-tmp/`. The hierarchical bootstrap lives in `INDEX.md` at the repo root and `@`-imports `INDEX.md`, `.ai/foundation/protocols.md`, `.ai/foundation/memory/MEMORY.md`, and `.ai/foundation/memory/project_no_gcp.md`.

**Why:** Of the three Agent-equivalent memory architectures discussed 2026-04-25 (native `INDEX.md` context engine, local SQLite/MCP, GCP Memory Bank), option 1 + sharing System OS paths preserves the Cognitive Sync Law without standing up parallel infrastructure. Option 3 (Memory Bank / Vertex AI) is forbidden by `project_no_gcp`. Option 2 (MCP via `mios-mcp.service` port 8051) remains a future fallback if `@`-imports prove flaky.

**How to apply:**
- When Agent uses `/memory add` or `save_memory`, it must route writes to `.ai/foundation/memories/journal.md` (episodic) or `.ai/foundation/memory/<kebab-name>.md` (semantic) — never to a Agent-only store.
- Both agents read the last ~200 lines of `journal.md` before acting; that is the inter-agent handoff.
- `.ai/agent-state/settings.json` carries Agent-CLI runtime config and points at INDEX.md as `contextFileName`. `.ai/agent-state/.env` has `GOOGLE_CLOUD_PROJECT=""` and `OTLP_GOOGLE_CLOUD_PROJECT=""` to neutralise GCP telemetry.
- Never propose Memory Bank / Vertex AI Vector Search even as an alternative — they violate `project_no_gcp`.
- If a future change splits the brain (parallel `.ai/agent-state/memories/`, separate journal), that's a Cognitive Sync Law violation — flag it and stop.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [mios-project/mios](https://github.com/mios-project/mios)
- **Sole Proprietor:** MiOS Project
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 MiOS Project -->
