# AI/MiOS Separation Design

**Date:** 2026-04-28
**Version:** v0.1.4
**Objective:** Separate AI tools from MiOS system scripts using FHS 3.0 and FOSS AI API patterns

---

## 🎯 Design Principles

### 1. **FHS 3.0 Compliance**
- AI tools follow Linux Filesystem Hierarchy Standard
- Clear separation of concerns: AI development vs OS infrastructure
- Proper use of `/usr/share`, `/usr/local/share`, `/var/lib`, `/etc`

### 2. **FOSS AI API Native**
- OpenAI-compatible structure
- Vendor-neutral (Ollama, llama.cpp, LocalAI, vLLM)
- Standard protocols (HTTP, REST, JSON)

### 3. **Linux Native Patterns**
- Standard directory structure
- XDG Base Directory compliance
- Proper permissions and ownership

---

## 📂 Proposed Directory Structure

### Current State (Mixed):
```
/mios/
├── .ai/                        # AI knowledge (GOOD location)
├── agents/                     # AI agents (research, etc.)
├── artifacts/ai-rag/           # AI RAG snapshots
├── automation/
│   ├── 37-ai-agnostic.sh      # AI-related (should move)
│   ├── 37-ollama-prep.sh      # AI-related (should move)
│   ├── 37-aichat.sh           # AI-related (should move)
│   └── ai-bootstrap.sh        # AI-related (should move)
├── tools/
│   └── generate-ai-manifest.py # AI-related (should move)
└── .well-known/ai-tools.json   # AI tools discovery
```

### Proposed Structure (Separated):

#### **MiOS System (Pure OS Infrastructure):**
```
/mios/
├── usr/                        # System binaries, libraries
│   ├── bin/mios*              # MiOS commands
│   ├── lib/                   # System libraries
│   ├── libexec/mios/          # MiOS internal executables
│   └── share/mios/            # MiOS application data
│       ├── PACKAGES.md
│       ├── tools/             # MiOS-only tools (build, sync, etc.)
│       └── automation/        # MiOS-only automation (numbered scripts)
├── etc/mios/                  # MiOS system configuration
├── var/lib/mios/              # MiOS state data
└── automation/                # Build automation (MiOS-only)
    ├── 00-*.sh through 90-*.sh (EXCLUDE 37-ai-*.sh)
    └── lib/                   # Common libraries
```

#### **AI Development Environment (Separate Concern):**
```
/mios/
├── .ai/                       # AI knowledge base (OpenAI-compatible)
│   ├── KNOWLEDGE-BASE.md      # Consolidated knowledge
│   ├── system-prompt.md       # FOSS AI prompts
│   ├── context.json           # Project context
│   ├── tools.json             # Function definitions
│   ├── rag-config.yaml        # RAG configuration
│   └── foundation/            # AI agent foundation
│       ├── memories/          # Episodic memory
│       ├── protocols.md       # AI protocols
│       └── commands/          # AI commands
│
├── ai-tools/                  # AI development tools (NEW)
│   ├── bin/                   # AI tool executables
│   │   ├── generate-ai-manifest
│   │   └── ai-context-update
│   ├── lib/                   # AI libraries
│   │   └── python/            # Python AI libs
│   ├── automation/            # AI automation scripts (MOVED)
│   │   ├── ai-bootstrap.sh
│   │   ├── ai-agnostic.sh
│   │   ├── ollama-prep.sh
│   │   └── aichat-setup.sh
│   ├── agents/                # AI agents (MOVED)
│   │   └── research/          # Research agent
│   ├── rag/                   # RAG artifacts (MOVED)
│   │   ├── snapshots/         # RAG snapshots
│   │   ├── manifests/         # RAG manifests
│   │   └── knowledge-graphs/  # Knowledge graphs
│   └── README.md              # AI tools documentation
│
├── .well-known/               # Discovery endpoints
│   ├── ai-tools.json          # AI tools discovery
│   └── llms.txt               # LLM configuration
│
└── ai-context.json            # Root AI context (legacy, to deprecate)
```

---

## 🔄 Migration Plan

### Phase 1: Create AI Tools Structure
```bash
mkdir -p ai-tools/{bin,lib/python,automation,agents,rag/{snapshots,manifests,knowledge-graphs}}
```

### Phase 2: Move AI Scripts from automation/
**Move these files:**
- `automation/37-ai-agnostic.sh` → `ai-tools/automation/ai-agnostic.sh`
- `automation/37-ollama-prep.sh` → `ai-tools/automation/ollama-prep.sh`
- `automation/37-aichat.sh` → `ai-tools/automation/aichat-setup.sh`
- `automation/ai-bootstrap.sh` → `ai-tools/automation/ai-bootstrap.sh`

**Remove from Containerfile:** These should NOT be in the OS image

### Phase 3: Move AI Agents
**Move:**
- `agents/research/` → `ai-tools/agents/research/`

**Keep:** `agents/` directory for future MiOS system agents (non-AI)

### Phase 4: Move AI RAG Artifacts
**Move:**
- `artifacts/ai-rag/*.tar.gz` → `ai-tools/rag/snapshots/`
- `artifacts/ai-rag/mios-knowledge-graph.json` → `ai-tools/rag/knowledge-graphs/`
- `artifacts/ai-rag/rag-manifest.yaml` → `ai-tools/rag/manifests/`

### Phase 5: Move AI Tools
**Move:**
- `tools/generate-ai-manifest.py` → `ai-tools/bin/generate-ai-manifest` (make executable)

### Phase 6: Update References
**Update all references in:**
- Containerfile (remove AI script references)
- Documentation (.ai/KNOWLEDGE-BASE.md)
- Build scripts (ensure they skip ai-tools/)
- .gitignore (ensure ai-tools/rag/snapshots/ ignored if needed)

---

## 📋 File Classification

### **MiOS System Scripts (Keep in automation/):**
```
00-base-install.sh
01-rpmfusion.sh
05-crowdsec.sh
08-system-files-overlay.sh
10-packages-core.sh
11-packages-gui.sh
12-virtualization.sh
13-ceph-k3s.sh
19-*.sh (all numbered scripts)
20-services.sh
25-firewall-ports.sh
30-*.sh (all numbered scripts)
31-user.sh
34-gpu-detect.sh
40-*.sh through 90-*.sh (EXCEPT 37-ai-*)
build.sh
lib/common.sh
lib/packages.sh
lib/logging.sh
```

### **AI Development Scripts (Move to ai-tools/):**
```
37-ai-agnostic.sh       → ai-tools/automation/ai-agnostic.sh
37-ollama-prep.sh       → ai-tools/automation/ollama-prep.sh
37-aichat.sh            → ai-tools/automation/aichat-setup.sh
ai-bootstrap.sh         → ai-tools/automation/ai-bootstrap.sh
```

### **AI Knowledge (Keep in .ai/):**
```
.ai/KNOWLEDGE-BASE.md
.ai/system-prompt.md
.ai/context.json
.ai/tools.json
.ai/rag-config.yaml
.ai/prompt-templates.json
.ai/foundation/
```

### **AI Agents (Move to ai-tools/):**
```
agents/research/        → ai-tools/agents/research/
```

### **AI Artifacts (Move to ai-tools/):**
```
artifacts/ai-rag/       → ai-tools/rag/
```

---

## 🎯 Benefits of Separation

### 1. **Clear Separation of Concerns**
- **MiOS System:** Pure OS infrastructure (bootc, systemd, packages, security)
- **AI Tools:** Development, RAG, agents, knowledge management

### 2. **FHS Compliance**
- AI tools NOT in OS image (developer concern, not runtime)
- MiOS system follows strict FHS 3.0
- Clear boundaries for package management

### 3. **FOSS AI API Native**
- AI tools use standard protocols
- OpenAI-compatible structure
- Easy integration with Ollama, llama.cpp, LocalAI, vLLM

### 4. **Build Optimization**
- Smaller OS image (no AI dev tools)
- Faster builds (skip AI processing)
- Clear what's in container vs what's in repo

### 5. **Better Documentation**
- Clear README for AI tools
- Separate docs for MiOS system
- No confusion between OS and AI development

---

## 📝 Implementation Checklist

- [ ] Create `ai-tools/` directory structure
- [ ] Move AI automation scripts from `automation/`
- [ ] Move AI agents from `agents/`
- [ ] Move AI RAG artifacts from `artifacts/ai-rag/`
- [ ] Move AI tools from `tools/`
- [ ] Create `ai-tools/README.md`
- [ ] Create `ai-tools/MANIFEST.json`
- [ ] Update `.gitignore` for AI artifacts
- [ ] Update Containerfile (remove AI script references)
- [ ] Update `.ai/KNOWLEDGE-BASE.md`
- [ ] Update root `README.md`
- [ ] Validate no broken references
- [ ] Test build without AI scripts

---

## 🔗 Standard Paths (Post-Migration)

### MiOS System:
```
/mios/usr/share/mios/           # MiOS application data
/mios/usr/bin/mios*             # MiOS commands
/mios/etc/mios/                 # MiOS configuration
/mios/var/lib/mios/             # MiOS state
/mios/automation/               # MiOS build automation
```

### AI Development:
```
/mios/.ai/                      # AI knowledge base (OpenAI-compatible)
/mios/ai-tools/                 # AI development tools
/mios/.well-known/ai-tools.json # AI discovery endpoint
```

### Clear Boundary:
- **Everything in `ai-tools/`** = Development concern, NOT in OS image
- **Everything in `automation/` (excluding ai-*)** = OS build scripts
- **Everything in `.ai/`** = AI knowledge, NOT executable scripts

---

## ✅ Validation Criteria

After migration, verify:
1. ✅ No AI scripts in `automation/` (except build.sh calling them conditionally)
2. ✅ All AI tools in `ai-tools/`
3. ✅ `.ai/` contains only knowledge/config, NO executable scripts
4. ✅ Containerfile does NOT reference `ai-tools/`
5. ✅ Build succeeds without AI tools
6. ✅ All references updated
7. ✅ Documentation accurate

---

**Status:** 📋 Design Complete - Ready for implementation.
