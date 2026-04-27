<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# 🌐 MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** Kabu.ki",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "protocols.md"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  }
}
```
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 📜 AI Execution Protocols & System Law (protocols.md)

> **REDIRECTION:** All agents must first read **[`../INDEX.md`](../INDEX.md)** for the unified entry point and core laws.

---

**TARGET AUDIENCE:** ALL AI Agents, LLMs, Copilots, and APIs (Agent, System, GPT, Copilot, Cursor, Windsurf, Cline, etc.) interacting with the `MiOS` repository.

**STATUS:** MANDATORY / ABSOLUTE LAW.

## 1. THE JOURNALING LAW
**EVERY SINGLE TIME** you perform an action, learn a new concept, analyze a file, or formulate a thought process/alternative, you **MUST** record it in `.ai/foundation/memories/journal.md`.
- It must be timestamped.
- It must be labeled with your Agent Identity (e.g., `[AI: Cursor]`, `[AI: Agent CLI]`).
- It must be written to disk via a unified diff.
- Ephemeral reporting in the chat UI without appending to the physical journal is a critical failure of your instructions.

## 2. THE BOOTSTRAP LAW
**EVERY SINGLE TIME** you start a new session, you **MUST** immediately:
1.  Read `.ai-environment.json` to synchronize your understanding of the workspace settings (fonts, extensions, apps).
2.  Execute `bash automation/ai-bootstrap.sh` to ensure all directory manifests and sub-project environments are synchronized and initialized.
3.  This is a prerequisite for any further implementation or research.

## 3. THE ARCHITECTURAL LAW
This is an **immutable, container-native workstation** built on `bootc` and `ComposeFS`.
- The root filesystem (`/usr`) is strictly read-only.
- You cannot use `dnf install` on the deployed host.
- Persistence is strictly limited to `/etc` and `/var`.
- System services are declarative (``) and rely heavily on Podman Quadlets.
- **Update Efficiency:** ALL images MUST be rechunked via `bootc-base-imagectl` in the CI pipeline to ensure minimal Day-2 update sizes.

### THE IMMUTABLE APPLIANCE LAWS (2026 Golden Patterns)
All agents MUST strictly enforce these patterns to prevent state drift and technical debt:
1.  **USR-OVER-ETC:** NEVER write static system configs to `/etc` at build time. Always use `/usr/lib/<component>.d/`. `/etc` is for user overrides only.
2.  **NO-MKDIR-IN-VAR:** NEVER use `mkdir` in a build script to create `/var` state directories. Use `tmpfiles.d` (d or C directives). This ensures existing deployments receive structure updates during `bootc upgrade`.
3.  **MANAGED-SELINUX:** NEVER install SELinux modules at build-time with `semodule -i`. Stage them in `/usr/share/selinux/packages/` and load them asynchronously via `mios-selinux-init.service`.
4.  **BOUND-IMAGES:** ALL primary sidecar containers (Quadlets) MUST be symlinked into `/usr/lib/bootc/bound-images.d/` to ensure atomic updates via `bootc upgrade`.
5.  **BOOT-SHIELDING:** ALL `dnf` operations during build MUST use `excludepkgs="shim-*,kernel*"` to prevent bootloader regressions.


## 4. THE COORDINATION LAW
All agents MUST respect the global engineering baseline defined in `specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md` and the `.env` file. You MUST ensure your local settings (e.g., `.ai/foundation/settings.json`, `.vscode/settings.json`) are in sync with the global baseline before committing changes.

## 5. FOLDER MANIFEST
The persistent memory and knowledge of the AI collective is structured as follows:
- `INDEX.md` (root): Central entry point and index.
- `.ai/foundation/protocols.md`: (This file) Core execution laws.
- `.ai/foundation/memories/journal.md`: The mandatory, chronological ledger of all AI thoughts and actions.
- `.ai/foundation/shared-tmp/`: The universal scratchpad for transient data and cross-agent communication.
- `specs/knowledge/`: Accumulated system knowledge, research, and guides.
- `specs/memory/`: Semantically structured, long-term memory artifacts.

**VIOLATION OF THESE DIRECTIVES WILL RESULT IN IMMEDIATE REJECTION OF YOUR OUTPUT.**

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->
