# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# CloudWS-bootc Knowledge Base

This directory is the **AI-context reference library** for CloudWS-bootc.
It collects every research compendium, technical reference, and
operational guide produced during the project's development, plus the
engineering-blueprint DOCX files and legacy changelogs.

Files here are **reference material**, not instructions. Claude Code,
Gemini CLI, and other agents are expected to read from this directory
when they need background — but authoritative project rules live in:

- [`../../CLAUDE.md`](../../CLAUDE.md) — primary AI instruction file
- [`../../GEMINI.md`](../../GEMINI.md) — Gemini mirror
- [`../../AGENTS.md`](../../AGENTS.md) — generic-agent mirror
- [`../../.github/copilot-instructions.md`](../../.github/copilot-instructions.md) — Copilot rules
- [`../../.ai-context/knowledge-base.md`](../../.ai-context/knowledge-base.md) — historical audit log
- [`../PACKAGES.md`](../PACKAGES.md) — single source of truth for packages

---

## Directory layout

```
docs/knowledge/
├── research/              ← technical-intelligence reports
├── guides/                ← operational / troubleshooting guides
├── blueprints/            ← engineering blueprint .docx files
└── changelogs-legacy/     ← v1.x–v2.1.x changelogs kept for provenance
```

---

## `research/` — technical-intelligence reports

Long-form research produced while designing and debugging CloudWS-bootc.
Read these when you need the *why* behind an architectural decision, or
when a new upstream ecosystem change (bootc, Universal Blue, NVIDIA CDI,
cosign, composefs, etc.) needs contextualizing.

| # | Document | Topic |
|---|----------|-------|
| 01 | `01-bootc-ecosystem-advances-2025-2026.md` | Bootc ecosystem strategic analysis for 2025-2026 |
| 02 | `02-building-cloudws-intelligence-report.md` | Complete technical intelligence report on CloudWS-bootc architecture |
| 03 | `03-comprehensive-research-compendium.md` | Comprehensive research compendium — Fedora Rawhide bootc immutable workstation OS |
| 04 | `04-technical-reference-7-solutions.md` | 7 practical solutions for immutable workstation deployment |
| 05 | `05-upstream-adoption-playbook.md` | Upstream adoption playbook — sequencing plan for a signed, multi-variant Fedora bootc |
| 06 | `06-v2_1_6-release-implementation-plan.md` | v2.1.6 release: CI fix, cosign keyless signing, full implementation plan |
| 07 | `07-v2_1-resolving-build-failures.md` | v2.1: resolving every build and boot failure |
| 08 | `08-gnome-50-fedora-rawhide-package-guide.md` | GNOME 50 on Fedora Rawhide — complete package reference and configuration guide |
| 09 | `09-integrating-ceph-cephadm-k3s.md` | Integrating Ceph, Cephadm, and K3s into CloudWS-bootc |
| 10 | `10-vfio-gpu-passthrough-fedora-2025.md` | Linux VFIO GPU passthrough tools on Fedora — 2025 packaging and ecosystem analysis |
| 11 | `11-minimal-gnome-strategy-analysis.md` | Minimal GNOME desktop strategy — package removal and build-up analysis |
| 12 | `12-minimal-gnome-definitive-strategy.md` | Minimal GNOME for Fedora Rawhide bootc — the definitive package strategy |
| 13 | `13-technical-audit-bootc-ecosystem.md` | Technical audit of the bootc ecosystem for CloudWS-bootc |
| 14 | `14-upstream-bootc-ecosystem-fixes.md` | Upstream bootc ecosystem fixes — mapping runtime issues to proven solutions |
| 15 | `15-compass-artifact-1.md` | Compass research artifact 1 |
| 16 | `16-compass-artifact-2.md` | Compass research artifact 2 |

**Reading order for a new collaborator / AI agent onboarding:**
→ 03 (compendium) → 02 (intelligence report) → 13 (audit) → 14 (fixes) → 01 (strategic direction) → topic-specific docs as needed.

---

## `guides/` — operational / troubleshooting guides

How-to material for the toolkit side of CloudWS-bootc: VFIO passthrough,
CPU pinning for gaming / high-throughput VMs, Looking Glass display
capture, and the standalone full-system provisioning script.

| Document | Purpose |
|----------|---------|
| `cpu-isolation-guide.md` | CPU isolation — concept, kernel params, cgroup boundaries |
| `cpu-isolation-optimization-notes.md` | Optimization notes accumulated across builds |
| `cpu-isolation-preset-corrections.md` | Preset corrections by CPU family (Zen 3/4/5, Intel hybrid) |
| `cpu-isolator-script-improvements.md` | Script-level improvements, idempotency, edge cases |
| `looking-glass-integration.md` | Looking Glass build + kvmfr + udev + Gamescope integration |
| `vfio-toolkit-readme.md` | VFIO configurator toolkit — passing GPUs / USB controllers into VMs |
| `vm-cpu-pin-manager-readme.md` | VM CPU pin manager — pinning vCPUs to host physical cores |
| `cloudws-full-script-readme.md` | Legacy `cloudws-full.sh` — standalone one-shot provisioner |

These documents describe the **out-of-image toolkit** that runs *on the
booted system*, not the build-time provisioning scripts. Build-time
logic lives in `../../scripts/` and `../../system_files/`.

---

## `blueprints/` — engineering blueprint DOCX files

Formal engineering documents authored in Microsoft Word format. Read
these when you need the "executive summary" view of CloudWS-bootc's
architecture.

| Document | Purpose |
|----------|---------|
| `CloudWS-Engineering-Blueprint.docx` | Overall engineering blueprint |
| `CloudWS-bootc-Blueprint.docx` | bootc-specific blueprint |

---

## `changelogs-legacy/` — pre-v2.2 changelogs

Historical changelogs kept for provenance. The **current** changelog is
at [`../../CHANGELOG.md`](../../CHANGELOG.md) and the per-release
fragments are in [`../changelogs/`](../changelogs/).

| Document | Covers |
|----------|--------|
| `CHANGELOG-v1.3.0.md` | v1.3.0 Ecosystem Intelligence Update |
| `UPDATE-v1_1-CHANGELOG.txt` | v1.1 legacy changelog |
| `QUICKSTART-legacy.txt` | Pre-v2 quickstart |
| `CHAINING-GUIDE-legacy.txt` | Pre-v2 profiler/toolkit chaining guide |
| `TOOLKIT-OVERVIEW-legacy.txt` | Pre-v2 toolkit overview |
| `FIX-REFERENCE-legacy.txt` | Pre-v2 build-fix quick reference |

**Do not** treat legacy changelogs as current state. Cross-reference
with `../../CHANGELOG.md` and the `VERSION` file before acting on
anything here.

---

## How AI agents should use this directory

1. **Default to not reading.** The primary instruction files
   (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`) contain the rules. These
   research docs are background.
2. **When a question requires background**, search semantically:
   "How does NVIDIA CDI interact with bootc?" → read
   `10-vfio-gpu-passthrough-fedora-2025.md` and
   `09-integrating-ceph-cephadm-k3s.md`.
3. **When an upstream change lands that affects this project**,
   check if it's already tracked in `01-bootc-ecosystem-advances-2025-2026.md`
   or `14-upstream-bootc-ecosystem-fixes.md` before proposing a response.
4. **Never quote these documents as a source of hard rules.** The hard
   rules live in `CLAUDE.md` §3 and are the only rules. Research docs
   explain *why* the rules exist; they do not override them.
5. **DOCX blueprints require conversion before inline use.** If an
   agent needs their content programmatically, use `pandoc` or
   `python-docx` — don't attempt to read binary DOCX as text.

---

*This index is generated as part of the CloudWS-bootc AI tooling
export. When documents are added or removed, regenerate the tables in
this file so it stays accurate.*

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
