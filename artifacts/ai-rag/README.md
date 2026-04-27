# MiOS AI RAG Artifacts

**Version:** v0.1.2  
**Generated:** 2026-04-27  
**Compression:** 928 MB → 752 KB (99.92% reduction)

## Artifacts in This Directory

This directory contains **GENERATED** AI RAG distribution artifacts:

1. **mios-knowledge-graph.json** (3.3 KB)
   - Structured knowledge graph (machine-readable)

2. **mios-context-TIMESTAMP.tar.gz** (752 KB)
   - Complete compressed repository context

3. **rag-manifest.yaml** (1.9 KB)
   - FOSS AI RAG configuration

4. **script-inventory.json** (8.2 KB)
   - Complete automation script catalog

5. **mios-docs-TIMESTAMP.tar.gz** (31 KB)
   - Core documentation bundle

## Documentation (Source of Truth)

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

## Quick Start

```bash
# 1. Extract context
tar -xzf mios-context-*.tar.gz -C ~/mios-rag

# 2. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b

# 3. See full integration guide
cat ../specs/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md
```

## Regenerate Artifacts

To regenerate these artifacts after documentation updates:

```bash
# Run compression script (references specs/ai-integration/ as source)
bash /tmp/compress-for-ai-rag.sh
```

---

**Documentation:** [specs/ai-integration/](../../specs/ai-integration/)  
**Repository:** https://github.com/mios-project/mios  
**License:** Personal Property - MiOS Project
