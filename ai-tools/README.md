# MiOS AI Development Tools

**Version:** v0.1.4
**Date:** 2026-04-28
**Type:** AI Development Environment (Separate from MiOS System)

---

## 🎯 Purpose

This directory contains AI development tools, agents, and knowledge artifacts **separate from the MiOS operating system**. These tools are for AI development, RAG (Retrieval-Augmented Generation), and agent-based workflows.

**Important:** These tools are **NOT** part of the MiOS OS image. They are development-time tools for working with AI systems.

---

## 📂 Directory Structure

```
ai-tools/
├── bin/                    # AI tool executables
│   └── generate-ai-manifest     # Generate AI manifests
│
├── lib/                    # AI libraries
│   └── python/             # Python AI libraries
│
├── automation/             # AI automation scripts
│   ├── ai-agnostic.sh      # AI environment configuration (vendor-neutral)
│   ├── ollama-prep.sh      # Ollama setup and configuration
│   ├── aichat-setup.sh     # aichat CLI setup
│   └── ai-bootstrap.sh     # AI environment bootstrap
│
├── agents/                 # AI agents
│   └── research/           # Research agent (Vertex AI integration)
│
├── rag/                    # RAG (Retrieval-Augmented Generation) artifacts
│   ├── snapshots/          # RAG snapshot archives (.tar.gz, .tar.xz)
│   ├── manifests/          # RAG manifests (YAML, JSON)
│   └── knowledge-graphs/   # Knowledge graphs
│
└── README.md               # This file
```

---

## 🚀 Quick Start

### Prerequisites:
- MiOS v0.1.4 or later
- FOSS AI API (Ollama, llama.cpp, LocalAI, or vLLM)
- Python 3.11+ (for agents)

### Setup AI Environment:
```bash
# Run AI bootstrap (vendor-neutral setup)
./ai-tools/automation/ai-bootstrap.sh

# Or set up Ollama specifically
./ai-tools/automation/ollama-prep.sh
```

---

## 📋 AI Automation Scripts

### 1. `automation/ai-agnostic.sh`
**Purpose:** Vendor-neutral AI environment configuration

**What it does:**
- Sets up AI endpoint configuration
- Configures OpenAI-compatible API settings
- Works with any FOSS AI API (Ollama, llama.cpp, LocalAI, vLLM)

**Usage:**
```bash
./ai-tools/automation/ai-agnostic.sh
```

**Environment Variables:**
```bash
MIOS_AI_ENDPOINT="http://localhost:11434"  # Default: Ollama
MIOS_AI_MODEL="llama3.1:8b"
MIOS_AI_API_KEY=""  # Optional for FOSS APIs
```

---

### 2. `automation/ollama-prep.sh`
**Purpose:** Ollama-specific setup and model management

**What it does:**
- Installs Ollama (if not present)
- Pulls recommended models (llama3.1:8b, codellama:13b)
- Sets up systemd service
- Configures OpenAI-compatible endpoint

**Usage:**
```bash
./ai-tools/automation/ollama-prep.sh
```

**Models Installed:**
- `llama3.1:8b` - General-purpose LLM
- `codellama:13b` - Code generation
- `nomic-embed-text` - Text embeddings

---

### 3. `automation/aichat-setup.sh`
**Purpose:** aichat CLI installation and configuration

**What it does:**
- Installs aichat CLI tool
- Configures for local FOSS APIs
- Sets up default model

**Usage:**
```bash
./ai-tools/automation/aichat-setup.sh
```

---

### 4. `automation/ai-bootstrap.sh`
**Purpose:** Complete AI environment initialization

**What it does:**
- Runs all AI setup scripts
- Synchronizes manifests
- Initializes RAG environment

**Usage:**
```bash
./ai-tools/automation/ai-bootstrap.sh
```

---

## 🤖 AI Agents

### Research Agent (`agents/research/`)
**Type:** Vertex AI-integrated research agent

**Purpose:** Multi-model AI research and analysis

**Setup:**
```bash
cd ai-tools/agents/research
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Usage:**
```bash
python ai-tools/agents/research/app/agent.py
```

**Configuration:**
- `config/config-1.json` - Primary configuration
- `config/config-2.json` - Alternative configuration
- `config/launch_vapo.py` - Vertex AI launch script

---

## 📚 RAG Artifacts

### Snapshots (`rag/snapshots/`)
**Contains:** Compressed RAG knowledge archives

**Format:**
- `.tar.gz` - gzip compression
- `.tar.xz` - LZMA2 compression (better compression)

**Files:**
- `mios-complete-rag-*.tar.gz` - Complete RAG snapshot
- `mios-complete-rag-*.tar.xz` - Complete RAG snapshot (XZ)
- `mios-ai-knowledge-complete-*.tar.gz` - AI knowledge snapshot

### Manifests (`rag/manifests/`)
**Contains:** RAG configuration and metadata

**Files:**
- `rag-manifest.yaml` - RAG configuration (YAML)
- `script-inventory.json` - Script inventory

### Knowledge Graphs (`rag/knowledge-graphs/`)
**Contains:** Knowledge graph representations

**Files:**
- `mios-knowledge-graph.json` - Complete knowledge graph

---

## 🛠️ AI Tools

### `bin/generate-ai-manifest`
**Purpose:** Generate AI manifest files

**Usage:**
```bash
./ai-tools/bin/generate-ai-manifest
```

**Output:** Updates AI manifests in `.ai/` directory

---

## 🔗 Integration with MiOS

### Relationship:
- **MiOS System** (`/mios/automation/`, `/mios/usr/`) - OS infrastructure
- **AI Tools** (`/mios/ai-tools/`) - Development tools (NOT in OS image)
- **AI Knowledge** (`/mios/.ai/`) - Knowledge base (config only, NO executables)

### Separation:
```
MiOS System (Runtime):
- automation/00-*.sh through automation/90-*.sh (EXCEPT 37-ai-*)
- usr/bin/mios*
- etc/mios/
- var/lib/mios/

AI Development (Build/Dev Time Only):
- ai-tools/automation/
- ai-tools/agents/
- ai-tools/rag/
- .ai/ (knowledge only, NO scripts)
```

---

## 🎯 FOSS AI API Support

### Supported APIs (Priority Order):

1. **Ollama** (http://localhost:11434)
   - **Recommended** - Best FOSS experience
   - Models: llama3.1:8b, codellama:13b, mistral:7b
   - OpenAI-compatible `/v1/chat/completions`

2. **llama.cpp** (http://localhost:8080)
   - Native inference, GGUF format
   - CPU/GPU acceleration
   - OpenAI-compatible

3. **LocalAI** (http://localhost:8080)
   - Drop-in OpenAI replacement
   - Multi-backend support

4. **vLLM** (http://localhost:8000)
   - Production-grade serving
   - Full OpenAI compatibility

### Standard Request Format:
```json
{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant"},
    {"role": "user", "content": "Hello"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048
}
```

---

## 📝 Environment Variables

### AI Configuration:
```bash
# Endpoint
export MIOS_AI_ENDPOINT="http://localhost:11434"

# Model
export MIOS_AI_MODEL="llama3.1:8b"

# API Key (optional for FOSS)
export MIOS_AI_API_KEY=""

# Provider-specific
export OLLAMA_HOST="http://localhost:11434"
export LLAMACPP_HOST="http://localhost:8080"
export LOCALAI_HOST="http://localhost:8080"
export VLLM_HOST="http://localhost:8000"
```

---

## 🔍 Troubleshooting

### Issue: AI scripts not found
**Solution:** These scripts are NOT in the OS image. They're in the repository only.

### Issue: Ollama not responding
**Check:**
```bash
systemctl status ollama
curl http://localhost:11434/api/tags
```

### Issue: Models not loading
**Diagnose:**
```bash
ollama list
ollama pull llama3.1:8b
```

---

## 📖 Documentation

### Related Files:
- [.ai/KNOWLEDGE-BASE.md](../.ai/KNOWLEDGE-BASE.md) - AI knowledge base
- [.ai/system-prompt.md](../.ai/system-prompt.md) - AI prompts
- [.ai/README.md](../.ai/README.md) - AI environment overview
- [docs/AI-MIOS-SEPARATION-DESIGN.md](../docs/AI-MIOS-SEPARATION-DESIGN.md) - Separation design

### External Resources:
- Ollama: https://ollama.ai
- llama.cpp: https://github.com/ggerganov/llama.cpp
- LocalAI: https://localai.io
- vLLM: https://docs.vllm.ai

---

## ✅ Best Practices

1. **Use FOSS APIs First** - Prioritize Ollama > llama.cpp > LocalAI > vLLM
2. **Keep AI Tools Separate** - Do NOT add to MiOS OS image
3. **Use Standard Protocols** - OpenAI-compatible APIs only
4. **Version Control RAG** - Keep snapshots compressed (.tar.xz preferred)
5. **Document Models** - Track which models are used where

---

## 🚫 What NOT to Do

❌ Do NOT add ai-tools/ scripts to Containerfile
❌ Do NOT put executable scripts in .ai/
❌ Do NOT mix AI tools with MiOS system scripts
❌ Do NOT use proprietary AI APIs (use FOSS)
❌ Do NOT commit large RAG snapshots uncompressed

---

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Total Scripts** | 4 |
| **Total Agents** | 1 (research) |
| **RAG Snapshots** | 7 archives |
| **Knowledge Graphs** | 1 |
| **Supported APIs** | 4 (Ollama, llama.cpp, LocalAI, vLLM) |

---

**Status:** ✅ Active Development Environment
**License:** Personal Property (MiOS-DEV)
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
