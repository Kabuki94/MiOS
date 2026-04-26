# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# Universal AI Memory (Level 1)
## Repository: MiOS
## Basis: Claude OS | Mirror: Google Gemini

### Synchronized Project State
- **Shared Memories**: `.claude/memories/` (Journal, Vaults)
- **Shared Scratchpad**: `.claude/shared-tmp/` (Universal TMPDIR)
- **Baseline**: v2.1.0
- **Mandate**: Cognitive Mirror Architecture (Twin agents, one brain)

### Active Protocols
- **Journaling**: Both agents write to [`.claude/memories/journal.md`](../memories/journal.md).
- **Communication**: Inter-agent data exchange via `.claude/shared-tmp/`.
- **Implementation**: Gemini executes; Claude remembers; both synchronize.
- **Gemini bootstrap**: Hierarchical context via [`GEMINI.md`](../../GEMINI.md) (option 1 — see [gemini-bootstrap.md](gemini-bootstrap.md)). Gemini reads the same `.claude/` paths; no parallel store.

### Project memories
- [No GCP](project_no_gcp.md) — MiOS does not target Google Cloud Platform.
- [Gemini bootstrap](gemini-bootstrap.md) — Cognitive Mirror via GEMINI.md hierarchical context engine (option 1).

### Architecture Update Complete (2026-04-25)
- Shared scratchpad provisioned.
- `AI.md` and `.ai-rules` updated to formalize the **Cognitive Mirror** relationship.
- All AI metadata consolidated into the shared Claude OS basis.

### Session-Init Fix Pass (2026-04-25 by Claude Opus 4.7)
- ✅ **Merge conflict resolved** in `.claude/memories/journal.md` (markers dropped lines 1665/1701/1740; both pivot-summary and daily-research blocks preserved chronologically).
- ✅ **Upstream-work-plan T2.5 marked DONE** — `bootc completion bash` already at `Containerfile:154`.
- ✅ **`push-to-github.ps1` rewritten** as canonical v2.1.0 release deliverable per `/push-version` skill (clone → optional staged-dir overlay → VERSION bump → CHANGELOG stamp → commit → push). Removed broken forward to nonexistent `push-v2.1.0.ps1`.
- ✅ **`.gemini/.env` GCP refs neutralized** — `GOOGLE_CLOUD_PROJECT` / `OTLP_GOOGLE_CLOUD_PROJECT` set to empty; documented `project_no_gcp` rule inline.
- ✅ **`CHANGELOG.md` reordered** — 2026-04-25 v2.1.0 block now at top, followed by 2026-04-22 v2.1.0, then v0.1.x descending. Written via Python script (`.claude/shared-tmp/changelog-rewrite.py`) under explicit one-shot Kabu authorisation ("yes! FIX please Claude" 2026-04-25). Edit/Write deny rule still in place; exception was authorisation, not policy change.

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
