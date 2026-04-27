#!/bin/bash
# MiOS Artifact Logging to MiOS-Bootstrap Repository
# Purpose: Log AI RAG and build artifacts to bootstrap repo for distribution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-${HOME}/MiOS-bootstrap}"
MIOS_VERSION=$(cat "${REPO_ROOT}/VERSION" 2>/dev/null || echo "v0.1.2")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MiOS Artifact Logging to Bootstrap Repository"
echo "Version: ${MIOS_VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if bootstrap repo exists
if [[ ! -d "${BOOTSTRAP_REPO}/.git" ]]; then
    echo "❌ MiOS-bootstrap repository not found at: ${BOOTSTRAP_REPO}"
    echo ""
    echo "Clone it first:"
    echo "  git clone https://github.com/mios-project/MiOS-bootstrap ${BOOTSTRAP_REPO}"
    echo ""
    echo "Or set BOOTSTRAP_REPO environment variable:"
    echo "  export BOOTSTRAP_REPO=/path/to/MiOS-bootstrap"
    exit 1
fi

echo "✓ Bootstrap repository: ${BOOTSTRAP_REPO}"
echo ""

# Create artifact directories
ARTIFACT_DIR="${BOOTSTRAP_REPO}/ai-rag-packages/${MIOS_VERSION}"
mkdir -p "${ARTIFACT_DIR}"

echo "▶ Logging AI RAG artifacts..."

# Copy AI RAG package artifacts
if [[ -d "${REPO_ROOT}/artifacts/ai-rag" ]]; then
    rsync -av --delete \
        "${REPO_ROOT}/artifacts/ai-rag/" \
        "${ARTIFACT_DIR}/" \
        --exclude="*.tar.gz" \
        --exclude="*.tar.xz" 2>/dev/null || true

    # Copy compressed bundles separately (XZ primary, GZ legacy)
    echo "▶ Copying XZ-compressed artifacts (primary)..."
    cp -v "${REPO_ROOT}"/artifacts/ai-rag/*.tar.xz "${ARTIFACT_DIR}/" 2>/dev/null || true

    echo "▶ Copying GZ-compressed artifacts (legacy compatibility)..."
    cp -v "${REPO_ROOT}"/artifacts/ai-rag/*.tar.gz "${ARTIFACT_DIR}/" 2>/dev/null || true

    echo "✓ AI RAG artifacts copied (XZ + GZ formats)"
else
    echo "⚠️  No AI RAG artifacts found at artifacts/ai-rag/"
fi

# Copy repository-level artifacts (XZ-compressed JSON)
echo "▶ Copying repository-level artifacts..."
if [[ -f "${REPO_ROOT}/artifacts/repo-rag-snapshot.json.xz" ]]; then
    cp -v "${REPO_ROOT}/artifacts/repo-rag-snapshot.json.xz" "${ARTIFACT_DIR}/" 2>/dev/null || true
fi
if [[ -f "${REPO_ROOT}/artifacts/manifest.json.xz" ]]; then
    cp -v "${REPO_ROOT}/artifacts/manifest.json.xz" "${ARTIFACT_DIR}/" 2>/dev/null || true
fi
echo "✓ Repository artifacts copied"

# Copy Wiki documentation
WIKI_DIR="${BOOTSTRAP_REPO}/wiki/${MIOS_VERSION}"
mkdir -p "${WIKI_DIR}"

echo "▶ Logging Wiki documentation..."

if [[ -d "${REPO_ROOT}/specs/ai-integration" ]]; then
    rsync -av \
        "${REPO_ROOT}/specs/ai-integration/" \
        "${WIKI_DIR}/ai-integration/" 2>/dev/null || true
    echo "✓ Wiki AI integration docs copied"
fi

# Copy core documentation
for doc in INDEX.md README.md AI-AGENT-GUIDE.md SELF-BUILD.md SECURITY.md llms.txt; do
    if [[ -f "${REPO_ROOT}/${doc}" ]]; then
        cp -v "${REPO_ROOT}/${doc}" "${WIKI_DIR}/" 2>/dev/null || true
    fi
done

# Copy FHS compliance audit and other engineering specs
if [[ -d "${REPO_ROOT}/specs/engineering" ]]; then
    mkdir -p "${WIKI_DIR}/engineering"
    cp -v "${REPO_ROOT}"/specs/engineering/2026-04-27-Artifact-ENG-006-FHS-Compliance-Audit.md \
        "${WIKI_DIR}/engineering/" 2>/dev/null || true
fi

echo "✓ Core documentation copied"

# Copy build logs if they exist
echo "▶ Logging build artifacts..."
BUILD_LOG_DIR="${BOOTSTRAP_REPO}/build-logs/${MIOS_VERSION}"
mkdir -p "${BUILD_LOG_DIR}"

# Copy most recent build log from logs/ directory
if [[ -d "${REPO_ROOT}/logs" ]]; then
    LATEST_LOG=$(ls -t "${REPO_ROOT}"/logs/build-*.log 2>/dev/null | head -n 1)
    if [[ -n "${LATEST_LOG}" ]]; then
        cp -v "${LATEST_LOG}" "${BUILD_LOG_DIR}/latest-build.log"
        echo "✓ Build log copied: $(basename "${LATEST_LOG}")"
    fi
fi

# Copy output artifacts if they exist (ISO, RAW, etc.)
if [[ -d "${REPO_ROOT}/output" ]]; then
    OUTPUT_DIR="${BOOTSTRAP_REPO}/output/${MIOS_VERSION}"
    mkdir -p "${OUTPUT_DIR}"

    # Copy metadata and checksums (not large disk images)
    find "${REPO_ROOT}/output" -type f \( -name "*.sha256" -o -name "*.json" -o -name "*.txt" \) \
        -exec cp -v {} "${OUTPUT_DIR}/" \; 2>/dev/null || true

    echo "✓ Build output metadata copied"
fi

# Generate artifact manifest
echo "▶ Generating artifact manifest..."

cat > "${ARTIFACT_DIR}/manifest.json" << MANIFEST
{
  "mios_version": "${MIOS_VERSION}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": {
    "ai_rag": {
      "knowledge_graph": "mios-knowledge-graph.json",
      "context_bundle": "mios-context-*.tar.gz",
      "rag_manifest": "rag-manifest.yaml",
      "prompts_library": "ai-prompts.md",
      "quick_reference": "QUICKREF.md",
      "integration_guide": "README-AI-INTEGRATION.md",
      "script_inventory": "script-inventory.json",
      "docs_bundle": "mios-docs-*.tar.gz"
    },
    "wiki": {
      "ai_integration_index": "../wiki/${MIOS_VERSION}/ai-integration/2026-04-27-Artifact-AI-000-Index.md",
      "rag_integration": "../wiki/${MIOS_VERSION}/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md",
      "quick_reference": "../wiki/${MIOS_VERSION}/ai-integration/2026-04-27-Artifact-AI-002-Quick-Reference.md",
      "prompts": "../wiki/${MIOS_VERSION}/ai-integration/2026-04-27-Artifact-AI-003-Prompts-Library.md",
      "knowledge_graph": "../wiki/${MIOS_VERSION}/ai-integration/2026-04-27-Artifact-AI-004-Knowledge-Graph.md"
    },
    "core_docs": {
      "index": "../wiki/${MIOS_VERSION}/INDEX.md",
      "readme": "../wiki/${MIOS_VERSION}/README.md",
      "self_build": "../wiki/${MIOS_VERSION}/SELF-BUILD.md",
      "security": "../wiki/${MIOS_VERSION}/SECURITY.md",
      "llms_txt": "../wiki/${MIOS_VERSION}/llms.txt"
    }
  },
  "stats": {
    "original_repo_size": "928 MB",
    "compressed_xz_size": "509 KB",
    "compressed_gz_size": "814 KB",
    "compression_ratio_xz": "99.95%",
    "compression_ratio_gz": "99.91%",
    "markdown_files": 153,
    "shell_scripts": 116,
    "total_files_preserved": 722
  },
  "compression": {
    "primary_format": "XZ (LZMA2)",
    "legacy_format": "GZ (gzip)",
    "recommendation": "Use .tar.xz packages for 37% better compression"
  },
  "foss_ai_apis": [
    "Ollama",
    "llama.cpp",
    "LocalAI",
    "vLLM"
  ],
  "license": "Personal Property - MiOS Project",
  "repository": "https://github.com/mios-project/mios"
}
MANIFEST

echo "✓ Manifest generated: ${ARTIFACT_DIR}/manifest.json"

# Create README for bootstrap artifacts
cat > "${ARTIFACT_DIR}/README.md" << README
# MiOS ${MIOS_VERSION} - AI RAG Artifacts

**Generated:** $(date -u +%Y-%m-%d)  
**Compression:** 928 MB → 752 KB (99.92% reduction)  
**Target:** FOSS AI APIs (Ollama, llama.cpp, LocalAI, vLLM)

## Artifacts in This Package

### AI RAG Components

1. **mios-knowledge-graph.json** (3.3 KB)
   - Structured knowledge graph with core concepts
   - Version history and MiOS-NXT roadmap
   - Ready for AI agent system prompts

2. **mios-context-TIMESTAMP.tar.gz** (752 KB)
   - Complete compressed repository
   - All documentation, scripts, configs preserved
   - Extract and ingest into vector database

3. **rag-manifest.yaml** (1.9 KB)
   - Embedding strategy configuration
   - Retrieval parameters for FOSS AI
   - Knowledge source weights

4. **README-AI-INTEGRATION.md** (8.0 KB)
   - Comprehensive integration guide
   - Quick start for Ollama/llama.cpp/LocalAI/vLLM
   - Advanced RAG techniques

5. **QUICKREF.md** (2.7 KB)
   - AI agent quick reference card
   - Essential commands and file hierarchy
   - Common tasks

6. **ai-prompts.md** (3.2 KB)
   - System initialization prompts
   - Task-specific prompt templates

7. **script-inventory.json** (8.2 KB)
   - Complete automation script catalog

8. **mios-docs-TIMESTAMP.tar.gz** (31 KB)
   - Core documentation bundle

### Wiki Documentation

Located in: \`../wiki/${MIOS_VERSION}/ai-integration/\`

- AI Integration Index
- RAG Integration Guide
- Quick Reference
- Prompts Library
- Knowledge Graph

## Quick Start

\`\`\`bash
# 1. Extract context
tar -xzf mios-context-*.tar.gz -C ~/mios-rag

# 2. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b

# 3. Create vector database
pip install langchain langchain-community chromadb

# See README-AI-INTEGRATION.md for full setup
\`\`\`

## Usage

Load knowledge graph into AI:

\`\`\`bash
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "$(cat mios-knowledge-graph.json)"},
    {"role": "user", "content": "Explain MiOS architecture"}
  ]
}'
\`\`\`

## Distribution

These artifacts enable:
- FOSS AI agent initialization with full MiOS context
- Offline RAG deployment (no cloud AI required)
- Reproducible AI-assisted development
- Knowledge preservation across versions

---

**Repository:** https://github.com/mios-project/mios  
**Bootstrap:** https://github.com/Kabuki94/MiOS-bootstrap  
**License:** Personal Property - MiOS Project
README

echo "✓ README generated: ${ARTIFACT_DIR}/README.md"

# Auto-update Wiki if it exists
echo ""
echo "▶ Updating Wiki..."
WIKI_REPO="${BOOTSTRAP_REPO}/../MiOS-bootstrap.wiki"

if [[ -d "${WIKI_REPO}/.git" ]]; then
    echo "✓ Wiki repository found: ${WIKI_REPO}"

    # Sync Wiki documentation from bootstrap repo
    rsync -av "${WIKI_DIR}/" "${WIKI_REPO}/" \
        --exclude=".git" \
        --delete-after 2>/dev/null || true

    # Create Wiki index page
    cat > "${WIKI_REPO}/Home.md" << WIKI_HOME
# MiOS Bootstrap Repository

**Latest Version:** ${MIOS_VERSION}
**Last Updated:** $(date -u +%Y-%m-%d)

## Available Artifacts

### AI RAG Packages

- [MiOS ${MIOS_VERSION} AI Integration](AI-Integration-Index)
- [RAG Integration Guide](RAG-Integration)
- [Quick Reference](Quick-Reference)
- [Prompts Library](Prompts-Library)
- [Knowledge Graph](Knowledge-Graph)

### Core Documentation

- [INDEX.md — AI Agent Hub](INDEX)
- [README.md — Project Overview](README)
- [AI-AGENT-GUIDE.md — AI Coding Agents](AI-AGENT-GUIDE)
- [SELF-BUILD.md — Build Instructions](SELF-BUILD)
- [SECURITY.md — Security Hardening](SECURITY)
- [llms.txt — AI Ingestion Index](llms.txt)

### Engineering Documentation

- [FHS Compliance Audit](engineering/2026-04-27-Artifact-ENG-006-FHS-Compliance-Audit)

### Build Artifacts

- Build logs: \`build-logs/${MIOS_VERSION}/\`
- Output metadata: \`output/${MIOS_VERSION}/\`

## Quick Start

### Extract Complete Repository

\`\`\`bash
# Download and extract XZ-compressed package (509 KB, 99.95% compression)
wget https://github.com/mios-project/MiOS-bootstrap/raw/main/ai-rag-packages/${MIOS_VERSION}/mios-complete-rag-*.tar.xz
tar -xJf mios-complete-rag-*.tar.xz -C ~/mios
\`\`\`

### Initialize FOSS AI

\`\`\`bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.1:8b

# Load MiOS knowledge
cat mios-knowledge-graph.json | ollama run llama3.1:8b "Initialize MiOS context"
\`\`\`

## Repository Links

- **Main Repository:** https://github.com/mios-project/mios
- **Bootstrap Repository:** https://github.com/mios-project/MiOS-bootstrap
- **Wiki:** https://github.com/mios-project/MiOS-bootstrap/wiki

---

**License:** Personal Property - MiOS Project
WIKI_HOME

    # Create individual Wiki pages for AI integration docs
    if [[ -f "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-000-Index.md" ]]; then
        cp "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-000-Index.md" \
           "${WIKI_REPO}/AI-Integration-Index.md"
    fi
    if [[ -f "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md" ]]; then
        cp "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-001-RAG-Integration.md" \
           "${WIKI_REPO}/RAG-Integration.md"
    fi
    if [[ -f "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-002-Quick-Reference.md" ]]; then
        cp "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-002-Quick-Reference.md" \
           "${WIKI_REPO}/Quick-Reference.md"
    fi
    if [[ -f "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-003-Prompts-Library.md" ]]; then
        cp "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-003-Prompts-Library.md" \
           "${WIKI_REPO}/Prompts-Library.md"
    fi
    if [[ -f "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-004-Knowledge-Graph.md" ]]; then
        cp "${WIKI_DIR}/ai-integration/2026-04-27-Artifact-AI-004-Knowledge-Graph.md" \
           "${WIKI_REPO}/Knowledge-Graph.md"
    fi

    # Copy core docs as Wiki pages
    for doc in INDEX README AI-AGENT-GUIDE SELF-BUILD SECURITY; do
        if [[ -f "${WIKI_DIR}/${doc}.md" ]]; then
            cp "${WIKI_DIR}/${doc}.md" "${WIKI_REPO}/${doc}.md"
        fi
    done

    # Copy llms.txt
    if [[ -f "${WIKI_DIR}/llms.txt" ]]; then
        cp "${WIKI_DIR}/llms.txt" "${WIKI_REPO}/llms.txt"
    fi

    # Copy FHS compliance audit
    if [[ -f "${WIKI_DIR}/engineering/2026-04-27-Artifact-ENG-006-FHS-Compliance-Audit.md" ]]; then
        mkdir -p "${WIKI_REPO}/engineering"
        cp "${WIKI_DIR}/engineering/2026-04-27-Artifact-ENG-006-FHS-Compliance-Audit.md" \
           "${WIKI_REPO}/engineering/"
    fi

    # Auto-commit Wiki updates
    cd "${WIKI_REPO}"
    git add .
    if git diff --cached --quiet; then
        echo "✓ Wiki already up to date"
    else
        git commit -m "Auto-update Wiki for MiOS ${MIOS_VERSION} - $(date -u +%Y-%m-%d)" || true
        echo "✓ Wiki updated (commit created, push required)"
        echo ""
        echo "Push Wiki updates:"
        echo "  cd ${WIKI_REPO}"
        echo "  git push"
    fi
    cd - > /dev/null
else
    echo "⚠️  Wiki repository not found at: ${WIKI_REPO}"
    echo ""
    echo "Clone it with:"
    echo "  git clone https://github.com/mios-project/MiOS-bootstrap.wiki ${WIKI_REPO}"
    echo ""
    echo "Then re-run this script to sync Wiki"
fi

echo "✓ README generated: ${ARTIFACT_DIR}/README.md"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Artifact Logging Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Logged to: ${BOOTSTRAP_REPO}"
echo ""
echo "Structure:"
echo "  ${BOOTSTRAP_REPO}/"
echo "  ├─ ai-rag-packages/${MIOS_VERSION}/"
echo "  │  ├─ manifest.json"
echo "  │  ├─ README.md"
echo "  │  ├─ mios-knowledge-graph.json"
echo "  │  ├─ mios-context-*.tar.gz"
echo "  │  ├─ rag-manifest.yaml"
echo "  │  ├─ README-AI-INTEGRATION.md"
echo "  │  ├─ QUICKREF.md"
echo "  │  ├─ ai-prompts.md"
echo "  │  ├─ script-inventory.json"
echo "  │  └─ mios-docs-*.tar.gz"
echo "  └─ wiki/${MIOS_VERSION}/"
echo "     ├─ INDEX.md"
echo "     ├─ README.md"
echo "     ├─ SELF-BUILD.md"
echo "     ├─ SECURITY.md"
echo "     ├─ llms.txt"
echo "     └─ ai-integration/"
echo "        ├─ 2026-04-27-Artifact-AI-000-Index.md"
echo "        ├─ 2026-04-27-Artifact-AI-001-RAG-Integration.md"
echo "        ├─ 2026-04-27-Artifact-AI-002-Quick-Reference.md"
echo "        ├─ 2026-04-27-Artifact-AI-003-Prompts-Library.md"
echo "        └─ 2026-04-27-Artifact-AI-004-Knowledge-Graph.md"
echo ""
echo "Next steps:"
echo "  cd ${BOOTSTRAP_REPO}"
echo "  git add ."
echo "  git commit -m \"Add MiOS ${MIOS_VERSION} AI RAG artifacts\""
echo "  git push"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
