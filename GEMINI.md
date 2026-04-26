# GEMINI.md — Gemini CLI Entry Point (MiOS)

> Hierarchical context bootstrap for Gemini CLI. The `@./` directives below are loaded in order.

@./AI.md
@./.claude/protocols.md
@./.claude/memory/MEMORY.md
@./.claude/memory/project_no_gcp.md

---

## Initialization Protocol

Upon first interaction, Gemini MUST:

1. **Load context** — verify the bootstrap chain above is loaded
2. **Sync environment** — read `.ai-environment.json` for workspace settings (fonts, extensions, apps)
3. **Execute bootstrap** — run `bash scripts/ai-bootstrap.sh` to regenerate manifests and initialize sub-project envs
4. **Sync memory** — read the last 200 lines of `.claude/memories/journal.md` for session handoff

## Memory Operations

- **Episodic:** Append to `.claude/memories/journal.md` with timestamp + `[AI: Gemini CLI]` tag
- **Semantic:** Create/update files in `.claude/memory/` (kebab-case filenames)
- **Scratchpad:** Use `.claude/shared-tmp/` for transient cross-agent data
- **Handoff:** Summarize your session at the end so the next agent has context

## Constraint: No GCP

MiOS does not target Google Cloud Platform. Reject any GCP-specific deliverables (GCE images,
Cloud Workstations, GAR push, GKE, Vertex AI Memory Bank, etc.).

## Settings

Runtime config in `.gemini/settings.json`. Do not create a Gemini-only memory store —
the Omni-Agent Law requires all agents to share `.claude/memories/` and `.claude/memory/`.
