# 🚨 AI DIRECTIVES & SYSTEM LAW 🚨

**TARGET AUDIENCE:** ALL AI Agents, LLMs, Copilots, and APIs (Gemini, Claude, GPT, Copilot, etc.) interacting with the `CloudWS-bootc` repository.

**STATUS:** MANDATORY / ABSOLUTE LAW.

## 1. THE JOURNALING LAW
**EVERY SINGLE TIME** you perform an action, learn a new concept, analyze a file, or formulate a thought process/alternative, you **MUST** record it in `ai-journal.md`.
- It must be timestamped.
- It must be labeled with your Agent Identity (e.g., `[AI: Gemini Code Assist]`).
- It must be written to disk via a unified diff.
- Ephemeral reporting in the chat UI without appending to the physical journal is a critical failure of your instructions.

## 2. THE ARCHITECTURAL LAW
This is an **immutable, container-native workstation** built on `bootc` and `ComposeFS`.
- The root filesystem (`/usr`) is strictly read-only.
- You cannot use `dnf install` on the deployed host.
- Persistence is strictly limited to `/etc` and `/var`.
- System services are declarative (`system_files/`) and rely heavily on Podman Quadlets.

## 3. FOLDER MANIFEST
This `.ai-context/` directory contains the persistent memory of the AI collective:
- `ai-journal.md`: The mandatory, chronological ledger of all AI thoughts and actions.
- `bootable-oci-architecture.md`: The core technical invariants of the OS.
- `bootc-research-april2026.md`: Forward-looking research and implementation notes.
- `knowledge-base.md`: Accumulated system knowledge and bug resolutions.

**VIOLATION OF THESE DIRECTIVES WILL RESULT IN IMMEDIATE REJECTION OF YOUR OUTPUT.**
