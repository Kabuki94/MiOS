# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
---
name: gemini-bootstrap
description: Gemini operates as a Cognitive Mirror bootstrapped from Claude OS via GEMINI.md (option 1) — shared resources, no parallel memory store
type: project
---

MiOS uses **Claude OS as the main engine** and **Gemini as a bootstrapped mirror** that reads from the same `.claude/memories/` and `.claude/shared-tmp/`. The hierarchical bootstrap lives in `GEMINI.md` at the repo root and `@`-imports `AI.md`, `.claude/protocols.md`, `.claude/memory/MEMORY.md`, and `.claude/memory/project_no_gcp.md`.

**Why:** Of the three Gemini-equivalent memory architectures discussed 2026-04-25 (native `GEMINI.md` context engine, local SQLite/MCP, GCP Memory Bank), option 1 + sharing Claude OS paths preserves the Cognitive Mirror Law without standing up parallel infrastructure. Option 3 (Memory Bank / Vertex AI) is forbidden by `project_no_gcp`. Option 2 (MCP via `mios-mcp.service` port 8051) remains a future fallback if `@`-imports prove flaky.

**How to apply:**
- When Gemini uses `/memory add` or `save_memory`, it must route writes to `.claude/memories/journal.md` (episodic) or `.claude/memory/<kebab-name>.md` (semantic) — never to a Gemini-only store.
- Both agents read the last ~200 lines of `journal.md` before acting; that is the inter-agent handoff.
- `.gemini/settings.json` carries Gemini-CLI runtime config and points at GEMINI.md as `contextFileName`. `.gemini/.env` has `GOOGLE_CLOUD_PROJECT=""` and `OTLP_GOOGLE_CLOUD_PROJECT=""` to neutralise GCP telemetry.
- Never propose Memory Bank / Vertex AI Vector Search even as an alternative — they violate `project_no_gcp`.
- If a future change splits the brain (parallel `.gemini/memories/`, separate journal), that's a Cognitive Mirror Law violation — flag it and stop.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
