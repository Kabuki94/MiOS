# CloudWS-bootc — Global AI Agent Standards

> **ATTENTION ALL AI AGENTS:** This file is the primary entry point for all AI interactions within this repository. You are **REQUIRED** to read this file and its referenced protocols before providing any answer or performing any action.

## 🤖 MANDATORY PROTOCOLS

1.  **JOURNALING LAW:** Every surgical change, architectural decision, and significant learning **MUST** be recorded in [`.ai-context/ai-journal.md`](./.ai-context/ai-journal.md) at the end of every turn.
2.  **SINGLE SOURCE OF TRUTH:**
    -   **Packages:** `docs/PACKAGES.md` is the only manifest. Never duplicate package lists.
    -   **Rules:** `CLAUDE.md` contains the authoritative hard build rules (§3) and deliverable expectations (§4).
    -   **Environment:** `.ai-context/AI-ENVIRONMENT.md` tracks the current architectural baseline.
3.  **USR-OVER-ETC:** Adhere to the `bootc` immutable pattern. System-provided configurations go in `/usr/lib/`, while `/etc/` is reserved for local state and overrides.

## 📂 DIRECTORY STRUCTURE & AGENT MAPPING

| File | Purpose | Audience |
|------|---------|----------|
| `AI.md` | This file: Global entry point and core laws. | **All Agents** |
| `CLAUDE.md` | Authoritative build rules & deliverables. | Claude Code & Generalist |
| `GEMINI.md` | Gemini-specific tool & CLI instructions. | Gemini CLI |
| `AGENTS.md` | Generic agent standard instructions. | Cursor, Aider, OpenAI, etc. |
| `.ai-rules` | Machine-readable rule set for linting. | All Agents |

## 🛠️ BEHAVIORAL STANDARDS

- **Zero Hallucination Policy:** If a `kargs.d` file or `systemd` unit requires specific syntax, verify it against the `bootc` or `systemd` documentation. Do NOT invent keys (e.g., `delete` in TOML).
- **Surgical Edits:** Prefer the `replace` tool for precise edits. Only use `write_file` for new or very small files.
- **Complete Artifacts:** When asked for a deliverable, provide **complete replacement files**. No patches, no diffs.
- **No Preambles:** In CLI mode, do not narrate your internal steps unless explicitly part of the "Explain Before Acting" mandate. High-signal technical output only.
- **Confirm Mutations:** Never delete files or perform destructive `git` operations without explicit user confirmation.

## 📜 RELATED PROTOCOLS

- [`.ai-context/AI-README.md`](./.ai-context/AI-README.md) — Detailed AI system law.
- [`.ai-context/AI-PROTOCOLS.md`](./.ai-context/AI-PROTOCOLS.md) — Execution and validation standards.
- [`.ai-context/knowledge-base.md`](./.ai-context/knowledge-base.md) — Historical audit and bug log.

---
*Last Updated: 2026-04-24. Failure to follow these rules will result in immediate rejection of output.*
