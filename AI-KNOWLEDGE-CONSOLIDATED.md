# MiOS AI Knowledge Consolidated - v0.1.3

**Generated:** 2026-04-28
**Purpose:** Complete condensed AI context, patterns, technologies, and tracking systems
**Target:** FOSS AI APIs, Open-Source LLMs, AI Agents (vendor-neutral)

---

## [NET] Project Identity

**Project:** MiOS (Immutable Cloud-Native Workstation OS)
**Version:** v0.1.3
**Type:** bootc-based container-to-OS system
**Base:** Fedora Rawhide + ucore-hci (Universal Blue CoreOS)
**Architecture:** Rootfs-native FHS 3.0 compliant
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
**Bootstrap Tracking:** https://github.com/Kabuki94/MiOS-bootstrap (secondary historical repo)

---

## [GOAL] FOSS AI API Agnostic Design

MiOS and all integrated tech stacks are **purely FOSS** and **AI API agnostic**, respecting Open-Source AI APIs and functionalities.

### Supported FOSS AI APIs

1. **Ollama** (http://localhost:11434)
   - Models: llama3.1:8b, codellama:13b, mistral:7b
   - Embedding: nomic-embed-text
   - Context window: 8192 tokens

2. **llama.cpp** (http://localhost:8080)
   - Native inference, GGUF format
   - CPU/GPU acceleration
   - Context window: 4096 tokens

3. **LocalAI** (http://localhost:8080)
   - OpenAI-compatible drop-in replacement
   - Model agnostic
   - Embedding: all-MiniLM-L6-v2

4. **vLLM** (http://localhost:8000)
   - Production-grade serving
   - Tensor parallelism support
   - Model: meta-llama/Llama-3.1-8B-Instruct

### AI Calling Protocol

```json
{
  "local_proxy": "http://localhost:8080/v1",
  "protocol_priority": [
    "OpenAI (FOSS)",
    "Gemini (Vertex)",
    "Claude (Anthropic)"
  ],
  "environment_mapping": {
    "key": "MIOS_AI_KEY",
    "model": "MIOS_AI_MODEL",
    "endpoint": "MIOS_AI_ENDPOINT"
  },
  "foss_llm_tagging": "MiOS-v0.1.3-Native"
}
```

---

## [BUILD] Core Technologies

### Container-Native Stack

- **bootc** v1.15+ - OCI image → bootable OS with atomic updates
- **composefs** - Filesystem verification with fs-verity
- **OSTree** - Version control for OS deployments
- **Podman** 5.x - Rootless container runtime
- **Quadlet** - systemd-native container management

### Base Image Chain

```
ghcr.io/ublue-os/ucore-hci:stable-nvidia
  └─ Fedora Rawhide (kernel-latest)
      └─ Pre-signed NVIDIA kmods (kmod-nvidia-open)
```

### Build Pipeline

1. **Containerfile** (2-stage OCI build)
   - Stage 1: `ctx` (scratch + automation scripts)
   - Stage 2: `main` (FROM base + apply overlays)

2. **automation/build.sh** (Master orchestrator)
   - 54 numbered scripts (01-99 prefix)
   - Unified logging with state tracking
   - Status card rendering

3. **Justfile** (Build targets)
   - `just build` - Build OCI image
   - `just rechunk` - Optimize for updates (5-10x smaller deltas)
   - `just iso` - Generate Anaconda installer
   - `just all` - Full artifact synthesis

---

## [TRACK] Variable Propagation System

### Single Source of Truth (SSOT)

**File:** `config/registry.toml`

```toml
[tags.VAR_VERSION]
value = "0.1.3"
description = "Current MiOS release version"
subscribers = ["VERSION", "root-manifest.json", "ai-context.json"]

[tags.IMG_BASE]
value = "ghcr.io/ublue-os/ucore-hci:stable-nvidia"
subscribers = ["Containerfile", "Justfile", "image-versions.yml"]

[tags.IMG_BIB]
value = "quay.io/centos-bootc/bootc-image-builder:latest"
subscribers = ["Justfile", "mios-build-local.ps1"]

[tags.USER_ADMIN]
value = "mios"
subscribers = ["automation/31-user.sh", "etc/mios/templates/default.env.toml"]

[tags.REGISTRY_DEFAULT]
value = "ghcr.io/kabuki94/mios"
subscribers = ["Justfile", "mios-build-local.ps1"]

[tags.PATH_ARTIFACTS]
value = "/usr/lib/mios/artifacts"
subscribers = ["automation/build.sh", "automation/90-generate-sbom.sh"]
```

### Propagation Mechanism

**Tool:** `tools/propagate.py`

```python
# Scans codebase for @track:TAG_NAME markers
# Updates values from registry.toml automatically
# Regex-based replacement preserving quotes and formatting
```

**Usage:**
```bash
python3 tools/propagate.py
python3 tools/propagate.py --dry-run  # Preview changes
```

### User Variable Propagation

**Build Entry Points:**
- CI/CD: GitHub Actions (`.github/workflows/build.yml`)
- Windows: `mios-build-local.ps1` (Podman Desktop)
- Linux: `just build` (sourcing user config)
- Fedora Server: Ignition scripts (automated deployment)

**User Configuration Files (XDG-compliant):**
```
~/.config/mios/
├── env.toml           # Environment overrides
├── images.toml        # OCI image preferences
├── build.toml         # Build configuration
└── flatpaks.list      # Flatpak applications
```

**Variable Loading:**
1. System defaults: `/etc/mios/templates/default.*.toml`
2. User overrides: `~/.config/mios/*.toml`
3. Environment variables (already set)
4. Command-line arguments

---

## [MEM] AI Knowledge Architecture

### Knowledge Graph Structure

**File:** `artifacts/ai-rag/mios-knowledge-graph.json` (105 lines)

```json
{
  "project": "MiOS",
  "version": "0.1.3",
  "type": "bootc-immutable-os",
  "base": "Fedora Rawhide + ucore-hci",
  "architecture": "rootfs-native",

  "live_documentation": {
    "wiki": "https://github.com/Kabuki94/MiOS-bootstrap/wiki",
    "update_frequency": "Every build, push, and local build entry point",
    "primary_source": "Wiki pages reflect latest state"
  },

  "core_concepts": {
    "bootc": "OCI image → bootable OS, atomic updates, composefs backend",
    "immutability": "/usr read-only, /etc + /var mutable, OSTree/composefs integrity",
    "self_building": "Podman + Buildah + bootc in-image, v1.x builds v1.(x+1)"
  },

  "immutable_laws": [
    "USR-OVER-ETC: No static config in /etc/ at build time, use /usr/lib/",
    "NO-MKDIR-IN-VAR: All /var dirs via tmpfiles.d, never mkdir in Containerfile",
    "MANAGED-SELINUX: semodule -i in RUN layer, or stage in /usr/share/selinux/",
    "BOUND-IMAGES: Quadlet containers in /usr/lib/bootc/bound-images.d/",
    "BOOTC-CONTAINER-LINT: Mandatory final validation"
  ]
}
```

### RAG Manifest

**File:** `artifacts/ai-rag/rag-manifest.yaml` (108 lines)

```yaml
project:
  name: MiOS
  version: 0.1.3
  type: bootc-immutable-os
  url: https://github.com/Kabuki94/MiOS-bootstrap

knowledge_sources:
  primary:
    - file: INDEX.md (weight: 1.0, type: architecture_laws)
    - file: usr/share/mios/PACKAGES.md (weight: 0.9, type: package_ssot)
    - file: SELF-BUILD.md (weight: 0.8, type: build_modes)
    - file: Containerfile (weight: 0.8, type: build_definition)

  secondary:
    - dir: specs/core/ (weight: 0.7, type: blueprints)
    - dir: specs/engineering/ (weight: 0.7, type: technical_specs)
    - dir: automation/ (weight: 0.6, type: scripts)

embedding_strategy:
  chunk_size: 512
  overlap: 50
  model: all-MiniLM-L6-v2  # HuggingFace (384 dims)

retrieval:
  top_k: 5
  score_threshold: 0.7
  rerank: true
```

### AI Context Hub

**File:** `ai-context.json`

```json
{
  "project": "MiOS-DEV",
  "version": "0.1.3",
  "manifests": {
    "root": "root-manifest.json",
    "documentation": "specs/manifest.json",
    "automation": "automation/manifest.json",
    "ai_tools": ".well-known/ai-tools.json"
  },
  "ai_api_agnostic_patterns": {
    "local_proxy": "http://localhost:8080/v1",
    "protocol_priority": ["OpenAI (FOSS)", "Gemini (Vertex)", "Claude (Anthropic)"],
    "foss_llm_tagging": "MiOS-v0.1.3-Native"
  }
}
```

---

## [TOOL] AI Function Calling Interface

**File:** `.well-known/ai-tools.json`

OpenAI Function Calling compatible interface for FOSS AI agents.

### Available Functions

1. **mios_update**
   - Description: Check for and apply MiOS system updates via bootc
   - Parameters: `json` (boolean), `check_only` (boolean)

2. **mios_status**
   - Description: Get detailed system and service status information
   - Parameters: `json` (boolean)

3. **mios_vfio_check**
   - Description: Check system readiness for VFIO GPU passthrough
   - Parameters: `json` (boolean)

4. **mios_vfio_toggle**
   - Description: Dynamically bind/unbind PCIe device for VM passthrough
   - Parameters: `json`, `pci_slot`, `action` (bind/unbind)

---

## [PKG] AI Artifact Packages

### Compressed Artifacts (99.95% compression)

**Location:** `artifacts/ai-rag/`

1. **mios-complete-rag-TIMESTAMP.tar.xz** (509 KB)
   - Complete repository bundle (722 files)
   - Original size: 928 MB → Compressed: 509 KB
   - XZ (LZMA2) compression

2. **mios-knowledge-complete-TIMESTAMP.tar.xz** (4.2 KB)
   - Knowledge graph + script inventory + RAG manifest
   - Rapid AI agent initialization package

3. **repo-rag-snapshot.json.xz** (588 KB)
   - Full semantic knowledge index
   - Uncompressed: 5.0 MB (88.3% compression)

4. **manifest.json.xz** (588 KB)
   - Complete project manifest with metadata
   - Uncompressed: 5.1 MB (88.5% compression)

### Extraction

```bash
# Complete repository
tar -xJf mios-complete-rag-*.tar.xz -C ~/mios-rag

# Knowledge only
tar -xJf mios-knowledge-complete-*.tar.xz
```

---

## [SYNC] Bootstrap & Wiki Integration

### MiOS-Bootstrap Repository

**Purpose:** Historical tracking and artifact distribution
**URL:** https://github.com/Kabuki94/MiOS-bootstrap
**Update Mechanism:** Automatic via `tools/prepare-bootstrap-native.sh`

### Wiki as Live Documentation

**URL:** https://github.com/Kabuki94/MiOS-bootstrap/wiki
**Update Frequency:** Every build, push, and local build entry point

**Key Wiki Pages:**
- Home: Current version and quick links
- AI-Integration-Index: AI agent hub
- RAG-Integration: RAG setup guide
- Quick-Reference: Fast lookup table
- Prompts-Library: AI prompt templates
- INDEX: Core architectural laws

**Priority:** Wiki pages are PRIMARY source for current/updated information. Static knowledge graph is snapshot - refer to Wiki for updates.

---

## [LOG] Logging & Artifacting

### Build Logging

**Location:** `/usr/lib/mios/logs/build.log` (during build)
**User Logs:** `~/.local/state/mios/logs/` (per-user builds)

**Master Build Runner:** `automation/build.sh`
- Unified logging with mask_filter (sensitive data redaction)
- State tracking: `/tmp/mios-build-state/*.ok|.warn|.fail`
- Status card rendering for progress

### Artifact Snapshot

**Mechanism:** Repository state embedded in image
```bash
# Created during build
tar -cJf /usr/lib/mios/artifacts/repo-snapshot.tar.xz -C /ctx .
```

**Purpose:** Self-contained diagnostic and rebuild capability

---

## [RES] Research & Documentation Tagging

### Artifact Naming Convention

Pattern: `YYYY-MM-DD-Artifact-XXX-NNN-Title.md`

- `XXX` = Category code (COR, ENG, KBX, AI, MEM, ADT, CHL)
- `NNN` = Sequential number within category

### Category Codes

- **COR**: Core specifications (Blueprint, Infrastructure, Operations)
- **ENG**: Engineering specs (Security, Testing, FHS Compliance)
- **KBX**: Knowledge base (Guides, research, deep-dives)
- **AI**: AI integration (RAG, prompts, knowledge graphs)
- **MEM**: Memory artifacts (Journal, research plans, work plans)
- **ADT**: Audit reports (Research summaries)
- **CHL**: Changelogs (Version history)

### Emoji-to-ASCII Mapping

**Tool:** `tools/remove-emojis.py`

Converts Unicode emojis to ASCII markers for compatibility:
- ▶️ → [START]
- ✅ → [OK]
- ❌ → [FAIL]
- ⚠️ → [WARN]
- 🧠 → [MEM]
- 🏗️ → [BUILD]
- 🔍 → [RES]
- 🌐 → [NET]
- ush, and local build entry point

**Key Wiki Pages:**
- Home: Current version and quick links
- AI-Integration-Index: AI agent hub
- RAG-Integration: RAG setup guide
- Quick-Reference: Fast lookup table
- Prompts-Library: AI prompt templates
- INDEX: Core architectural laws

**Priority:** Wiki pages are PRIMARY source for current/updated information. Static knowledge graph is snapshot - refer to Wiki for updates.

---

## [LOG] Logging & Artifacting

### Build Logging

**Location:** `/usr/lib/mios/logs/build.log` (during build)
**User Logs:** `~/.local/state/mios/logs/` (per-user builds)

**Master Build Runner:** `automation/build.sh`
- Unified logging with mask_filter (sensitive data redaction)
- State tracking: `/tmp/mios-build-state/*.ok|.warn|.fail`
- Status card rendering for progress

### Artifact Snapshot

**Mechanism:** Repository state embedded in image
```bash
# Created during build
tar -cJf /usr/lib/mios/artifacts/repo-snapshot.tar.xz -C /ctx .
```

**Purpose:** Self-contained diagnostic and rebuild capability

---

## [RES] Research & Documentation Tagging

### Artifact Naming Convention

Pattern: `YYYY-MM-DD-Artifact-XXX-NNN-Title.md`

- `XXX` = Category code (COR, ENG, KBX, AI, MEM, ADT, CHL)
- `NNN` = Sequential number within category

### Category Codes

- **COR**: Core specifications (Blueprint, Infrastructure, Operations)
- **ENG**: Engineering specs (Security, Testing, FHS Compliance)
- **KBX**: Knowledge base (Guides, research, deep-dives)
- **AI**: AI integration (RAG, prompts, knowledge graphs)
- **MEM**: Memory artifacts (Journal, research plans, work plans)
- **ADT**: Audit reports (Research summaries)
- **CHL**: Changelogs (Version history)

### Emoji-to-ASCII Mapping

**Tool:** `tools/remove-emojis.py`

Converts Unicode emojis to ASCII markers for compatibility:
- ▶️ → [START]
- ✅ → [OK]
- ❌ → [FAIL]
- ⚠️ → [WARN]
- 🧠 → [MEM]
- 🏗️ → [BUILD]
- 🔍 → [RES]
- 🌐 → [NET]
- 509 KB (99.95% compres� → [GOAL]
- 📦 → [PKG]
- 💻 → [TECH]
- 📊 → [STAT]
- 🔄 → [SYNC]
- 🛡️ → [SEC]
- 📚 → [DOC]
- 🔧 → [TOOL]

---

## [SEC] Immutable Laws & Architectural Patterns

### The 5 Golden Laws (2026 Patterns)

1. **USR-OVER-ETC**
   - NEVER write static configs to `/etc` at build time
   - Always use `/usr/lib/<component>.d/`
   - `/etc` is for user overrides only

2. **NO-MKDIR-IN-VAR**
   - NEVER use `mkdir` in build scripts for `/var` directories
   - Use `tmpfiles.d` (d or C directives)
   - Ensures structure updates propagate during `bootc upgrade`

3. **MANAGED-SELINUX**
   - NEVER install SELinux modules with `semodule -i` at build time
   - Stage in `/usr/share/selinux/packages/`
   - Load asynchronously via `mios-selinux-init.service`

4. **BOUND-IMAGES**
   - ALL primary Quadlets symlinked to `/usr/lib/bootc/bound-images.d/`
   - Ensures atomic updates via `bootc upgrade`

5. **BOOTC-CONTAINER-LINT**
   - Mandatory final validation in Containerfile
   - Enforces kernel hygiene, tmpfiles.d requirements

### FHS 3.0 Compliance

**Status:** 100% compliant (verified 2026-04-27)

**Filesystem Semantics:**
- `/usr` - Immutable, composefs-covered, read-only (all OS content)
- `/etc` - 3-way merge on upgrades (base ← local ← new)
- `/var` - Persistent state, excluded from updates
- `/run` - API filesystem, never ship content here
- `/usr/local` - Mutable by default in bootc derivatives

---

## [STAT] Project Statistics

### Repository Metrics

- **Shell scripts:** 120 files
- **Markdown docs:** 81 files
- **Automation scripts:** 54 numbered scripts (01-99)
- **Version references:** 176+ files
- **AI integration specs:** 7 files

### Code Metrics

- Containerfile: 116 lines
- automation/build.sh: 156 lines
- Justfile: 242 lines
- README.md: 160 lines

### AI Artifact Metrics

- Knowledge graph: 105 lines JSON
- RAG manifest: 108 lines YAML
- Script inventory: 234 lines JSON
- Complete RAG package: 509 KB (99.95% compression)

---

## [START] Quick Start for AI Agents

### Initialization Sequence

```bash
# 1. Load AI context
cat ai-context.json

# 2. Load knowledge graph
cat artifacts/ai-rag/mios-knowledge-graph.json

# 3. Read architectural laws
cat INDEX.md

# 4. Check Wiki for latest updates
curl https://github.com/Kabuki94/MiOS-bootstrap/wiki/Home

# 5. Review RAG manifest for integration
cat artifacts/ai-rag/rag-manifest.yaml
```

### Integration with FOSS AI

**Ollama Example:**
```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b

# Load MiOS knowledge
cat artifacts/ai-rag/mios-knowledge-graph.json | \
  ollama run llama3.1:8b "Load this MiOS knowledge graph as context"

# Query
echo "How does MiOS handle system updates?" | \
  ollama run llama3.1:8b --context mios
```

**LocalAI Example:**
```bash
# Start LocalAI
docker run -p 8080:8080 \
  -v $PWD/models:/models \
  quay.io/go-skynet/local-ai:latest

# Index MiOS docs
curl http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d @artifacts/ai-rag/mios-knowledge-graph.json
```

---

## [LINK] Key References

### Primary Documentation

- **INDEX.md** - AI agent hub, laws, directory map
- **README.md** - Project overview, quick deployment
- **SELF-BUILD.md** - 4 build modes (CI/CD, Windows, Linux, self-build)
- **USER-SPACE-GUIDE.md** - XDG configuration, user overrides
- **DEPLOY.md** - Linux FS native deployment guide

### AI Integration Specs

Location: `specs/ai-integration/`

- 2026-04-27-Artifact-AI-000-Index.md (Wiki landing page)
- 2026-04-27-Artifact-AI-001-RAG-Integration.md (Integration guide)
- 2026-04-27-Artifact-AI-002-Quick-Reference.md (Quick reference)
- 2026-04-27-Artifact-AI-003-Prompts-Library.md (AI prompts)
- 2026-04-27-Artifact-AI-004-Knowledge-Graph.md (Knowledge graph)
- 2026-04-27-Artifact-AI-005-Wiki-Discovery.md (Wiki patterns)
- 2026-04-27-Artifact-AI-006-Unified-Redirects.md (AI redirects)

### Technical Specifications

Location: `specs/engineering/`

- 2026-04-26-Artifact-ENG-002-Security.md (Security hardening)
- 2026-04-26-Artifact-ENG-003-Self-Build.md (Build architecture)
- 2026-04-26-Artifact-ENG-004-Testing.md (Test frameworks)
- 2026-04-27-Artifact-ENG-006-FHS-Compliance-Audit.md (FHS audit)
- 2026-04-27-Artifact-ENG-008-UserSpace-Separation.md (XDG patterns)

### Core Blueprints

Location: `specs/core/`

- 2026-04-26-Artifact-COR-001-Blueprint.md (Technical specs)
- 2026-04-26-Artifact-COR-002-Infrastructure.md (Hardware support)
- 2026-04-26-Artifact-COR-003-Manifest.md (Project manifest)
- 2026-04-26-Artifact-COR-004-Operations.md (Operational guide)

---

## [TECH] Technology Matching Standards

### Container Runtime

- Podman 5.x (rootless, daemonless)
- Buildah (image building)
- Skopeo (image operations)

### Image Format

- OCI (Open Container Initiative)
- Digest pinning with SHA256
- Multi-arch support (amd64, future: arm64)

### Update Mechanism

- bootc v1.15+ (container-to-OS)
- OSTree composefs backend
- Atomic rollback support
- Delta updates (rechunked for efficiency)

### Security Stack

- SELinux enforcing (Targeted policy)
- fapolicyd (application whitelisting)
- CrowdSec (IPS/IDS)
- fs-verity (filesystem verification)
- cosign (image signing)

### Desktop Environment

- GNOME 47+ (Wayland native)
- Flatpak (application sandboxing)
- XDG standards compliance

### Virtualization

- libvirt + QEMU/KVM
- VFIO GPU passthrough
- Looking Glass (low-latency VM display)
- Waydroid (Android containers)

### AI/ML Integration

- Ollama (local LLM serving)
- llama.cpp (native inference)
- LocalAI (OpenAI-compatible)
- vLLM (production serving)

---

**Generated:** 2026-04-28
**Version:** MiOS v0.1.3
**License:** Personal Property - MiOS-DEV
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
**Wiki:** https://github.com/Kabuki94/MiOS-bootstrap/wiki
