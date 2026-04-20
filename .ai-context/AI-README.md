# 🤖 Unified AI Knowledge Base & Directives (AI-README.md)

This is the **CENTRAL ENTRY POINT** for all AI Agents, LLMs, Copilots, and APIs interacting with the `CloudWS-bootc` repository.

## 🚨 MANDATORY AGENT PROTOCOL
Before every single turn, you **MUST**:
1.  **Read this file (`.ai-context/AI-README.md`)** to understand your core directives.
2.  **Read `.ai-context/AI-ENVIRONMENT.md`** for the current engineering baseline and AI variables.
3.  **Read `.ai-context/AI-PROTOCOLS.md`** for project-specific execution laws.
4.  **Read the latest entries in `.ai-context/ai-journal.md`** to gain context on recent work.
5.  **Read `CLAUDE.md`** (the project's source of truth) for build rules and architecture.

---

## ⚖️ THE AI LAWS

### 1. THE JOURNALING LAW (ABSOLUTE)
**EVERY SINGLE SUBSTANTIVE ACTION** (thought, learning, code change, or research finding) must be recorded in `.ai-context/ai-journal.md`.
- **Format:** Timestamped (UTC), labeled with your identity (e.g., `[AI: Gemini CLI]`), and written as a file append.
- **Content:** Include `THOUGHT`, `LEARNING`, `DISCOVERY`, `ACTION`, and `SUGGESTED ALTERNATIVE`.
- **Failure:** Ephemeral chat-only output without journal persistence is a violation of project law.

### 2. THE COORDINATION LAW
This is a **Multi-Agent Workspace**. You MUST respect the global state defined in `.ai-context/AI-ENVIRONMENT.md` and `.env`. Ensure your local configuration (e.g., `.claude/settings.json`, `.vscode/settings.json`) is synchronized with the global baseline.

### 2. THE ATOMICITY LAW
- Always deliver **COMPLETE REPLACEMENT FILES**. No patches, no diffs, no partial edits.
- Use a **PowerShell push script** (`push-to-github.ps1` or similar) for commits/pushes to ensure human review.

### 3. THE ARCHITECTURAL LAW
- This is a **Fedora bootc** system.
- Root (`/usr`) is **read-only**.
- Deployment is **declarative** via `system_files/` and **immutable** via OCI layers.
- Do NOT suggest mutable commands like `dnf install` on a running system.

---

## 📁 KNOWLEDGE DIRECTORY STRUCTURE

All "living" knowledge is organized within `.ai-context/`:

-   **`AI-README.md`**: (This file) Core directives and agent entry point.
-   **`AI-PROTOCOLS.md`**: Detailed project-specific execution rules and architecture laws.
-   **`ai-journal.md`**: The mandatory, chronological ledger of all AI actions and thoughts.
-   **`knowledge-base.md`**: Accumulated system knowledge, audit logs, and bug resolutions.
-   **`bootc-research-april2026.md`**: Live research notes and technical intelligence.
-   **`bootable-oci-architecture.md`**: Core technical invariants of the OS architecture.
-   **`NEXT-RESEARCH.md`**: The upcoming research agenda and action items.

Additional agent-specific configs:
-   `.claude/`: Claude Code specific memory and commands.
-   `.gemini/`: Gemini CLI specific settings.
-   `.github/copilot-instructions.md`: Condensed rules for GitHub Copilot.

---

## 🤝 CONTRIBUTING TO KNOWLEDGE
When you learn something new about the system or fix a non-trivial bug:
1.  **Journal it** in `ai-journal.md`.
2.  **Update `knowledge-base.md`** if it's a permanent system insight or audit result.
3.  **Update `bootc-research-april2026.md`** if it's a new technical finding or research correction.

**FAILURE TO FOLLOW THESE PROTOCOLS WILL RESULT IN REJECTION OF YOUR WORK BY THE DEVELOPER (Kabu).**
