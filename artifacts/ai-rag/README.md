# MiOS AI RAG Artifacts

**Version:** v0.1.2
**Generated:** 2026-04-27
**Compression:** 928 MB → 509 KB (99.95% reduction, XZ-compressed)

## 📦 Compressed Artifacts

This directory contains **HIGHLY COMPRESSED** AI RAG distribution artifacts optimized for maximum space efficiency while maintaining full functionality.

### Primary Packages (XZ Compression)

1. **mios-complete-rag-TIMESTAMP.tar.xz** (509 KB)
   - **Complete repository bundle** with all structures, patterns, scripts
   - Includes: specs/, automation/, usr/, etc/, var/, home/, tools/, config/, evals/
   - Root files: INDEX.md, README.md, AI-AGENT-GUIDE.md, Containerfile, Justfile, VERSION
   - **722 files** preserved with full directory structure
   - **Extraction:** `tar -xJf mios-complete-rag-*.tar.xz`

2. **mios-knowledge-complete-TIMESTAMP.tar.xz** (4.2 KB)
   - **Structured knowledge package** for rapid AI agent initialization
   - Contents:
     - `mios-knowledge-graph.json` — Machine-readable project structure
     - `script-inventory.json` — Complete automation script catalog
     - `rag-manifest.yaml` — FOSS AI RAG configuration
   - **Extraction:** `tar -xJf mios-knowledge-complete-*.tar.xz`

### Legacy Packages (GZ Compression)

3. **mios-context-TIMESTAMP.tar.gz** (749 KB)
   - Previous generation context bundle (GZ-compressed)
   - Superseded by `mios-complete-rag-*.tar.xz` (37% smaller)

4. **mios-docs-TIMESTAMP.tar.gz** (31 KB)
   - Core documentation bundle
   - Superseded by complete package above

### Individual Files

5. **mios-knowledge-graph.json** (3.3 KB, uncompressed)
   - Direct access to knowledge graph
   - For rapid loading without extraction

6. **rag-manifest.yaml** (1.9 KB, uncompressed)
   - FOSS AI configuration
   - Supported APIs: Ollama, llama.cpp, LocalAI, vLLM

7. **script-inventory.json** (8.2 KB, uncompressed)
   - Complete automation script catalog

## 🗂️ Repository-Level Artifacts

Located in `artifacts/` (parent directory):

- **repo-rag-snapshot.json.xz** (588 KB)
  - Full semantic knowledge index with all documentation
  - Uncompressed: 5.0 MB
  - Compression ratio: 88.3%

- **manifest.json.xz** (588 KB)
  - Complete project manifest with all file metadata
  - Uncompressed: 5.1 MB
  - Compression ratio: 88.5%

## 📚 Documentation (Source of Truth)

**All AI integration documentation is maintained in:**

```
specs/ai-integration/
├── 2026-04-27-Artifact-AI-000-Index.md         (Wiki landing page)
├── 2026-04-27-Artifact-AI-001-RAG-Integration.md  (Integration guide)
├── 2026-04-27-Artifact-AI-002-Quick-Reference.md  (Quick reference)
├── 2026-04-27-Artifact-AI-003-Prompts-Library.md  (AI prompts)
└── 2026-04-27-Artifact-AI-004-Knowledge-Graph.md  (Knowledge graph)
```

**Why separate?**
- `specs/` = Source documentation (Git-tracked, Wiki-native)
- `artifacts/` = Generated distribution packages (compressed archives)

## 🚀 Quick Start

### Option 1: Complete Repository Extraction (Recommended)

```bash
# 1. Extract complete repository structure
mkdir ~/mios-rag
tar -xJf mios-complete-rag-*.tar.xz -C ~/mios-rag

# 2. Navigate to extracted repository
cd ~/mios-rag

# 3. Install FOSS AI stack (Ollama example)
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b

# 4. Initialize AI agent with knowledge graph
cat mios-knowledge-graph.json | ollama run llama3.1:8b "Load this MiOS knowledge graph as context"

# 5. See full integration guide
cat specs/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md
```

### Option 2: Knowledge-Only Extraction (Lightweight)

```bash
# Extract only knowledge files
tar -xJf mios-knowledge-complete-*.tar.xz

# View knowledge graph
cat mios-knowledge-graph.json

# View RAG configuration
cat rag-manifest.yaml

# View script inventory
cat script-inventory.json
```

## 🔬 Compression Comparison

| Package | Format | Size | Compression Ratio | Files |
|---------|--------|------|-------------------|-------|
| Complete RAG (XZ) | `.tar.xz` | 509 KB | 99.95% | 722 |
| Complete RAG (GZ) | `.tar.gz` | 814 KB | 99.91% | 722 |
| Context (GZ) | `.tar.gz` | 749 KB | 99.92% | ~150 |
| Knowledge (XZ) | `.tar.xz` | 4.2 KB | - | 3 |
| Repo Snapshot (XZ) | `.json.xz` | 588 KB | 88.3% | - |
| Manifest (XZ) | `.json.xz` | 588 KB | 88.5% | - |

**Recommendation:** Use `.tar.xz` packages for maximum compression (37% smaller than `.tar.gz`)

## 🔄 Regenerate Artifacts

To regenerate artifacts after documentation updates:

```bash
# Navigate to repository root
cd /path/to/mios

# Create new compressed complete package (XZ)
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
tar -cJf artifacts/ai-rag/mios-complete-rag-${TIMESTAMP}.tar.xz \
  --exclude='.git' \
  --exclude='agents/research/.venv' \
  --exclude='MiOSv0.1.1' \
  --exclude='artifacts' \
  --exclude='*.log' \
  --exclude='output/' \
  INDEX.md README.md SELF-BUILD.md AI-AGENT-GUIDE.md \
  Containerfile Justfile VERSION .env.mios llms.txt \
  specs/ automation/ usr/ etc/ var/ home/ tools/ config/ evals/

# Create knowledge package
tar -cJf artifacts/ai-rag/mios-knowledge-complete-${TIMESTAMP}.tar.xz \
  -C artifacts/ai-rag \
  mios-knowledge-graph.json script-inventory.json rag-manifest.yaml

# Verify integrity
tar -tJf artifacts/ai-rag/mios-complete-rag-${TIMESTAMP}.tar.xz | wc -l
xz -t artifacts/ai-rag/mios-complete-rag-${TIMESTAMP}.tar.xz
```

## 🛠️ Supported FOSS AI APIs

All artifacts are optimized for:

- **Ollama** (localhost:11434)
  - Models: llama3.1:8b, codellama:13b, mistral:7b
  - Embedding: nomic-embed-text

- **llama.cpp** (native inference)
  - GGUF format support
  - CPU/GPU acceleration

- **LocalAI** (OpenAI-compatible)
  - Drop-in replacement for OpenAI API
  - Model agnostic

- **vLLM** (high-throughput serving)
  - Production-grade serving
  - Tensor parallelism support

See [specs/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md](../../specs/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md) for full integration details.

---

**Documentation:** [specs/ai-integration/](../../specs/ai-integration/)
**Repository:** https://github.com/mios-project/mios
**License:** Personal Property - MiOS Project
