<!-- [NET] MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/mios-project/mios -->
# [NET] MiOS
```json:knowledge
{
  "summary": "> **Proprietor:** MiOS-DEV",
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
> **Proprietor:** MiOS-DEV
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to MiOS-DEV
---
# Universal AI Memory (Level 1)
## Repository: MiOS
## Basis: System OS | Mirror: Google Agent

### Synchronized Project State
- **Shared Memories**: `.ai/foundation/memories/` (Journal, Vaults)
- **Shared Scratchpad**: `.ai/foundation/shared-tmp/` (Universal TMPDIR)
- **Baseline**: v0.1.3
- **Mandate**: Cognitive Sync Architecture (Twin agents, one brain)

### Active Protocols
- **Journaling**: Both agents write to [`.ai/foundation/memories/journal.md`](../memories/journal.md).
- **Communication**: Inter-agent data exchange via `.ai/foundation/shared-tmp/`.
- **Implementation**: Agent executes; System remembers; both synchronize.
- **Agent bootstrap**: Hierarchical context via [`INDEX.md`](../../INDEX.md) (option 1  see .ai/agent-state-bootstrap.md].ai/agent-state-bootstrap.md)). Agent reads the same `.ai/foundation/` paths; no parallel store.

### Project memories
- [No GCP](project_no_gcp.md)  MiOS does not target Google Cloud Platform.
- [Agent bootstrap].ai/agent-state-bootstrap.md)  Cognitive Sync via INDEX.md hierarchical context engine (option 1).

### Architecture Update Complete (2026-04-25)
- Shared scratchpad provisioned.
- `INDEX.md` and `.ai-rules` updated to formalize the **Cognitive Sync** relationship.
- All AI metadata consolidated into the shared System OS basis.

### Session-Init Fix Pass (2026-04-25 by System Opus 4.7)
- [OK] **Merge conflict resolved** in `.ai/foundation/memories/journal.md` (markers dropped lines 1665/1701/1740; both pivot-summary and daily-research blocks preserved chronologically).
- [OK] **Upstream-work-plan T2.5 marked DONE**  `bootc completion bash` already at `Containerfile:154`.
- [OK] **`push-to-github.ps1` rewritten** as canonical v0.1.3 release deliverable per `/push-version` skill (clone  optional staged-dir overlay  VERSION bump  CHANGELOG stamp  commit  push). Removed broken forward to nonexistent `push-v0.1.3.ps1`.
- [OK] **`.ai/agent-state/.env` GCP refs neutralized**  `GOOGLE_CLOUD_PROJECT` / `OTLP_GOOGLE_CLOUD_PROJECT` set to empty; documented `project_no_gcp` rule inline.
- [OK] **`CHANGELOG.md` reordered**  2026-04-25 v0.1.3 block now at top, followed by 2026-04-22 v0.1.3, then v0.1.x descending. Written via Python script (`.ai/foundation/shared-tmp/changelog-rewrite.py`) under explicit one-shot Kabu authorisation ("yes! FIX please System" 2026-04-25). Edit/Write deny rule still in place; exception was authorisation, not policy change.

---
###  Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osautomation/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [mios-project/mios](https://github.com/mios-project/mios)
- **Sole Proprietor:** MiOS-DEV
---
<!--  MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
