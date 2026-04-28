# MiOS AI Knowledge Base

**Version:** 2.0.0
**Generated:** 2026-04-28
**Target:** FOSS AI APIs (Ollama, llama.cpp, LocalAI, vLLM, LangChain, LlamaIndex)
**Format:** OpenAI-compatible, vendor-neutral

---

## Project Identity

**Name:** MiOS (Immutable Cloud-Native Workstation OS)
**Version:** v0.1.4
**Type:** bootc-based container-to-OS system
**Base:** Fedora Rawhide + ucore-hci (Universal Blue CoreOS)
**Architecture:** Rootfs-native, FHS 3.0 compliant
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
**Wiki:** https://github.com/Kabuki94/MiOS-bootstrap/wiki

---

## Core Technologies

### Build System
- **bootc** - Container-to-OS transformation
- **Podman/Buildah** - OCI image building
- **bootc-image-builder (BIB)** - Disk image generation
- **Fedora Rawhide** - Rolling release kernel
- **ucore-hci** - Universal Blue CoreOS base

### Hardware Support
- **NVIDIA** - Pre-signed kmods (kmod-nvidia-open)
- **AMD** - Mesa drivers + ROCm compute stack
- **Intel** - intel-compute-runtime + media drivers
- **VFIO** - GPU passthrough (Looking Glass, kvmfr)

### Security Stack
- **SELinux** - Enforcing mode with custom policies
- **fapolicyd** - Execution whitelisting
- **firewalld** - Network filtering
- **fs-verity** - Integrity verification (composefs)
- **Cosign** - Image verification
- **CrowdSec** - Intrusion detection
- **USBGuard** - Device control
- **Secure Boot** - UEFI firmware verification

### Container & Orchestration
- **Podman Quadlet** - Systemd-native containers
- **K3s** - Lightweight Kubernetes
- **Ceph** - Distributed storage (optional)
- **Moby Engine** - Docker compatibility

### Desktop & Remote Access
- **GNOME** - Wayland-only desktop (v50+)
- **RDP** - xrdp + xorgxrdp-glamor
- **Cockpit** - Web-based administration
- **Apache Guacamole** - Clientless remote desktop

---

## FOSS AI Integration

### Supported AI APIs (Priority Order)

1. **Ollama** (http://localhost:11434)
   - Models: llama3.1:8b, codellama:13b, mistral:7b, qwen2.5-coder:7b
   - Embedding: nomic-embed-text
   - Context: 8192 tokens
   - API: OpenAI-compatible `/v1/chat/completions`

2. **llama.cpp** (http://localhost:8080)
   - Native inference, GGUF format
   - CPU/GPU acceleration (CUDA, ROCm, oneAPI)
   - Context: 4096-32768 tokens (model-dependent)
   - API: OpenAI-compatible

3. **LocalAI** (http://localhost:8080)
   - Drop-in OpenAI replacement
   - Multi-backend (llama.cpp, whisper, stable-diffusion)
   - Embedding: all-MiniLM-L6-v2
   - Function calling support

4. **vLLM** (http://localhost:8000)
   - Production-grade serving
   - Tensor parallelism, paged attention
   - Models: meta-llama/Llama-3.1-8B-Instruct
   - API: Full OpenAI compatibility

### OpenAI API Standard Format

```json
{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "You are MiOS AI assistant..."},
    {"role": "user", "content": "Analyze build logs"}
  ],
  "temperature": 0.7,
  "max_tokens": 2048,
  "stream": false,
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "analyze_script",
        "description": "Analyze shell script for errors",
        "parameters": {
          "type": "object",
          "properties": {
            "script_path": {"type": "string"},
            "check_type": {"type": "string", "enum": ["syntax", "logic", "security"]}
          },
          "required": ["script_path"]
        }
      }
    }
  ]
}
```

### Environment Variables (API-Agnostic)

```bash
# Generic AI configuration
export MIOS_AI_ENDPOINT="http://localhost:11434"  # Default: Ollama
export MIOS_AI_MODEL="llama3.1:8b"
export MIOS_AI_API_KEY="${MIOS_AI_API_KEY:-}"     # Optional
export MIOS_AI_TEMPERATURE="0.7"
export MIOS_AI_MAX_TOKENS="2048"
export MIOS_AI_CONTEXT_WINDOW="8192"

# Provider-specific (for multi-provider setups)
export OLLAMA_HOST="http://localhost:11434"
export LLAMACPP_HOST="http://localhost:8080"
export LOCALAI_HOST="http://localhost:8080"
export VLLM_HOST="http://localhost:8000"

# Embedding service
export MIOS_EMBEDDING_ENDPOINT="http://localhost:11434"
export MIOS_EMBEDDING_MODEL="nomic-embed-text"
```

---

## Immutable Laws (Architecture Rules)

These are **absolute** - violations cause build failures or runtime issues:

1. **USR-OVER-ETC** - Never write static config to `/etc/` at build time. Use `/usr/lib/<component>.d/`. `/etc/` is for user overrides only.

2. **NO-MKDIR-IN-VAR** - Never `mkdir /var/...` in build scripts. Use `tmpfiles.d` (`d` or `C` directives) or `StateDirectory=` in systemd units. Exception: `mkdir /var/home` when symlinking `/home`.

3. **MANAGED-SELINUX** - `semodule -i` in Containerfile `RUN` layer is primary method. Fallback: stage `.te` in `/usr/share/selinux/packages/` and load via service.

4. **BOUND-IMAGES** - Primary quadlet containers MUST be symlinked to `/usr/lib/bootc/bound-images.d/` for atomic updates.

5. **BOOT-SHIELDING** - Use `excludepkgs="shim-*,kernel*"` in DNF operations. Exception: With rpm-ostree 2025.2+ and `/usr/lib/kernel/install.conf` containing `layout=ostree`, kernels can be upgraded.

6. **NOVA-CORE-BLACKLIST** - On Fedora 44+ (kernel 6.15+), blacklist both `nouveau` AND `nova_core` for NVIDIA proprietary driver.

7. **BOOTC-CONTAINER-LINT** - `RUN bootc container lint` MUST be the final Containerfile instruction. Enforces single kernel, valid kargs, `/var` backing, etc.

8. **NO-DNF-UPGRADE-UNCONDITIONAL** - Never `dnf -y upgrade` without package names. Use targeted upgrades for reproducibility.

9. **UNIFIED-AI-REDIRECTS** - AI integration MUST use agnostic variables (`MIOS_AI_*`) and target local proxy. FOSS-priority.

10. **PACKAGES-MD-SSOT** - All package installation via `usr/share/mios/PACKAGES.md` using `install_packages()`. No rogue `dnf install`.

---

## Build Pipeline

### Entry Points

1. **`build-mios.sh`** (PRIMARY - Fedora Server Bootstrap)
   - **ONE-LINER:** `curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/build-mios.sh | sudo bash`
   - **What it does:**
     - Clones repository from GitHub
     - Installs to FHS directories (merge-only, no deletions)
     - **Prompts for user configuration** (interactive):
       - Username (default: mios)
       - Password (SHA-512 hashed)
       - Hostname
       - Base image selection
       - Flatpak applications
       - AI configuration (model, endpoint, API key)
     - **Fully automated user-space initialization:**
       - Creates Linux user accounts with full group memberships (wheel, libvirt, kvm, video, render, docker)
       - Sets up XDG-compliant directories (~/.config/mios, ~/.local/share/mios, ~/.cache/mios, ~/.local/state/mios)
       - Creates configuration files (env.toml, images.toml, build.toml, flatpaks.list, ai.env)
       - Initializes Python virtual environment (~/.local/share/mios/venv)
       - Sets up dotfiles directory for build-time injection (~/.config/mios/dotfiles/)
       - Creates credentials directory with .gitignore (~/.config/mios/credentials/)
       - Sets correct ownership for all user files
     - Optionally builds OCI image
   - **Note:** This is the **COMPLETE automated entry script** - no separate `mios init-user-space` needed
   - Output: Fully configured system with user-space initialized + optionally `localhost/mios:latest`

2. **`just build`** (Developer workflow)
   - Runs artifact refresh, preflight checks, podman build
   - Assumes repository already cloned
   - Requires user-space already configured (use `just init-user-space` if needed)
   - Output: `localhost/mios:latest`

3. **`mios build`** (Native command - post-installation)
   - Available after `build-mios.sh` or `install.sh` has run
   - Syncs source, changes to `/usr/src/mios/`, runs build
   - User-space already initialized by `build-mios.sh`
   - Output: `localhost/mios:latest`

4. **Direct podman build** (Advanced)
   - `podman build --no-cache -t localhost/mios:latest .`
   - Requires manual configuration
   - Assumes repository present and configured

### Containerfile Stages

```
Stage 1: ctx (scratch)
  └─ COPY build context (automation/, usr/, etc/, var/, home/, tools/)

Stage 2: main (FROM ${BASE_IMAGE})
  ├─ COPY --from=ctx /ctx /ctx
  ├─ RUN 08-system-files-overlay.sh (apply rootfs)
  ├─ RUN automation/build.sh (execute 49 numbered scripts)
  ├─ RUN cleanup
  ├─ RUN bootc completion bash
  ├─ RUN mios-sysext-pack.sh
  ├─ RUN rm -rf /ctx && ostree container commit
  └─ RUN bootc container lint (FINAL VALIDATION)
```

### Master Orchestrator (automation/build.sh)

- Executes 49 numbered scripts in sequence
- State tracking: `/tmp/mios-build-state/*.{ok,fail,warn}`
- Logging: `/usr/lib/mios/logs/build.log`
- Exit 0 if all succeed, exit 1 if any fail
- Renders status card showing success/warn/fail counts

### Script Execution Order (Key Scripts)

```
01-repos.sh              # Fedora 44 overlay on ucore
02-kernel.sh             # Kernel config, creates /tmp/mios-kver
05-enable-external-repos.sh  # RPMFusion, etc.
10-gnome.sh              # Desktop environment
11-hardware.sh           # GPU drivers (NVIDIA, AMD, Intel)
12-virt.sh               # QEMU, libvirt, Looking Glass
13-ceph-k3s.sh           # Storage & orchestration
20-services.sh           # Systemd service configuration
25-firewall-ports.sh     # Firewall port configuration
31-user.sh               # User creation & authentication
34-gpu-detect.sh         # GPU detection (bare metal vs VM)
35-gpu-passthrough.sh    # VFIO setup
37-ai-agnostic.sh        # AI environment configuration (MOVED to ai-tools/automation/ai-agnostic.sh)
40-composefs-verity.sh   # Integrity verification
42-cosign-policy.sh      # Image verification
46-greenboot.sh          # Atomic rollback
47-hardening.sh          # Security hardening
49-finalize.sh           # Final configuration
99-cleanup.sh            # Image cleanup
```

### Build-Time Variables

**Note:** `build-mios.sh` automatically prompts for and sets these variables during bootstrap.

```bash
# Containerfile ARG (passed via --build-arg)
# build-mios.sh prompts for these and generates them automatically
MIOS_USER=mios                # Prompted: "Enter username (default: mios)"
MIOS_PASSWORD_HASH=...        # Prompted: "Enter password" → SHA-512 hashed automatically
MIOS_HOSTNAME=mios            # Prompted: "Enter hostname (default: mios)"
MIOS_FLATPAKS=                # Prompted: "Flatpak applications (comma-separated)"

# User-Editable (~/.config/mios/*.toml)
# build-mios.sh creates these files automatically based on prompts
MIOS_BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia  # Prompted: Base image selection (1-4)
MIOS_IMAGE_NAME=ghcr.io/kabuki94/mios:latest
MIOS_BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder:latest

# AI Configuration (Optional)
# build-mios.sh prompts: "Configure AI integration? (y/n)"
MIOS_AI_ENDPOINT=http://localhost:11434  # Prompted if AI enabled
MIOS_AI_MODEL=llama3.1:8b                # Prompted if AI enabled
MIOS_AI_API_KEY=                         # Prompted if AI enabled (stored in ~/.config/mios/ai.env mode 600)
```

### User-Space Initialization (Automated by build-mios.sh)

**`build-mios.sh` automatically handles all user-space setup:**

1. **User Account Creation**
   - Prompts for username (default: mios)
   - Prompts for password (SHA-512 hashed, confirmed)
   - Creates user via `systemd-sysusers`
   - Adds to required groups (wheel, libvirt, kvm, video, etc.)

2. **Home Directory Setup**
   - Creates `/var/home/${USER}` (FHS-compliant)
   - Copies from `/etc/skel/` (populated from repo `home/`)
   - Sets correct ownership and permissions

3. **Configuration Files**
   - Creates `~/.config/mios/env.toml` (user environment)
   - Creates `~/.config/mios/images.toml` (image configuration)
   - Creates `~/.config/mios/build.toml` (build configuration)
   - Creates `~/.config/mios/flatpaks.list` (flatpak app IDs)
   - Creates `~/.config/mios/ai.env` (AI secrets, mode 600)

4. **Dotfiles Injection**
   - If build context includes `/ctx/etc/mios/dotfiles/`, copies to home
   - Removes `.user` suffix from dotfile names
   - Sets up user-specific shell configuration

5. **Environment Variables**
   - Queues env/venv setup based on user inputs
   - All settings stored in XDG-compliant locations

6. **Credentials Storage**
   - Passwords stored as SHA-512 hashes only
   - API keys stored in mode 600 files
   - No plaintext credentials in logs or configs

**No separate `mios init-user-space` command needed** - it's fully integrated into `build-mios.sh`.

---

## Directory Structure (FHS 3.0)

```
/mios/                           # Repository root
├── usr/                         # System binaries & libraries (immutable)
│   ├── bin/                     # 13 command binaries (mios, iommu-groups, etc.)
│   ├── lib/                     # 222 library files (systemd units, presets, etc.)
│   ├── libexec/                 # 36 internal scripts
│   └── share/mios/              # Application data
│       ├── PACKAGES.md          # Package SSOT
│       ├── tools/               # Build & sync scripts
│       └── automation/          # Numbered build scripts
├── etc/                         # System configuration (templates)
│   ├── mios/                    # MiOS configuration templates
│   ├── systemd/system/          # Systemd unit overrides
│   └── dconf/                   # GNOME configuration
├── var/                         # Mutable state (tmpfiles.d managed)
│   ├── lib/mios/                # Build artifacts, snapshots
│   └── log/mios/                # Build logs
├── home/                        # User skeleton files (/etc/skel/)
├── automation/                  # Build automation (62 scripts)
│   ├── build.sh                 # Master orchestrator
│   ├── lib/                     # Shared libraries
│   │   ├── common.sh            # Logging, DNF config, masking
│   │   ├── packages.sh          # Package installation
│   │   └── masking.sh           # Credential protection
│   └── [0-9][0-9]-*.sh          # Numbered build scripts
├── tools/                       # Utility scripts (44 scripts)
├── specs/                       # Architectural documentation (43 docs)
│   ├── core/                    # Core architecture
│   ├── engineering/             # Engineering specs
│   ├── ai-integration/          # AI patterns
│   └── knowledge/               # Guides & research
├── docs/                        # User guides (5 guides)
├── evals/                       # Testing scripts
├── config/                      # Build configurations
│   ├── artifacts/               # BIB configs
│   └── ignition/                # Ignition configs
└── .ai/                         # AI integration files
    ├── KNOWLEDGE-BASE.md        # This file
    ├── context.json             # Unified context
    ├── system-prompt.md         # System prompt
    ├── tools.json               # Function definitions
    ├── variables.json           # Variable mappings
    └── foundation/              # Memory system
        └── memories/            # Semantic memory
```

---

## Package Management

### PACKAGES.md Pattern

All packages declared in `usr/share/mios/PACKAGES.md`:

````markdown
```packages-kernel
kernel
kernel-modules-extra
```

```packages-gnome
gnome-shell
gnome-terminal
gdm
```
````

### Installation Functions

```bash
# From automation/lib/packages.sh
source "${SCRIPT_DIR}/lib/packages.sh"

install_packages "category"              # Installs, continues on failure
install_packages_strict "category"       # Installs, fails if any package missing
install_packages_optional "category"     # Installs, never fails
```

### DNF Configuration

```bash
# From automation/lib/common.sh
DNF_BIN="dnf5"  # or "dnf" if dnf5 unavailable
DNF_SETOPT=(
    "--setopt=install_weak_deps=False"
    "--setopt=keepcache=True"
)
DNF_OPTS=(
    "--best"
    "--allowerasing"
)

# Usage
$DNF_BIN "${DNF_SETOPT[@]}" install -y "${DNF_OPTS[@]}" package-name
```

---

## Script Patterns

### Standard Script Template

```bash
#!/bin/bash
# MiOS v0.1.3 - NN-script-name: Brief description
#
# CHANGELOG v0.1.3:
#   - Change description
#
# DEPENDENCIES:
#   - Requires: 01-repos.sh (Fedora 44 repos)
#   - Creates: /tmp/mios-state-file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

log "Operation starting..."

# Script logic here
if ! command -v tool &>/dev/null; then
    warn "tool not found, skipping"
    exit 0
fi

operation || die "Operation failed"

log "Operation complete"
```

### Logging Functions

```bash
log "message"           # Info level (green timestamp)
warn "message"          # Warning level (yellow)
die "message"           # Error + exit 1 (red)
diag "message"          # Diagnostic info (blue)
```

### Error Handling Patterns

```bash
# Command existence check
if ! command -v tool &>/dev/null; then
    warn "tool not found, skipping"
    exit 0
fi

# Critical operation
operation || die "Operation failed"

# Optional operation
operation 2>/dev/null || true

# Validation after operation
systemd-sysusers --root=/ 2>/dev/null || true
if ! getent passwd "${USER}" >/dev/null; then
    die "Failed to create user ${USER}"
fi
```

---

## AI Function Calling

### Available Functions (tools.json schema)

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "analyze_build_log",
        "description": "Analyze MiOS build log for errors and warnings",
        "parameters": {
          "type": "object",
          "properties": {
            "log_path": {
              "type": "string",
              "description": "Path to build log file",
              "default": "/usr/lib/mios/logs/build.log"
            },
            "error_type": {
              "type": "string",
              "enum": ["all", "dnf", "systemd", "selinux", "bootc"],
              "description": "Type of errors to focus on"
            }
          },
          "required": ["log_path"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "validate_script",
        "description": "Validate shell script syntax and best practices",
        "parameters": {
          "type": "object",
          "properties": {
            "script_path": {"type": "string"},
            "check_shellcheck": {"type": "boolean", "default": true},
            "check_sources_common": {"type": "boolean", "default": true}
          },
          "required": ["script_path"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "query_packages",
        "description": "Query packages from PACKAGES.md",
        "parameters": {
          "type": "object",
          "properties": {
            "category": {
              "type": "string",
              "enum": ["kernel", "gnome", "virt", "gpu-nvidia", "gpu-amd", "gpu-intel", "security", "networking"]
            },
            "operation": {
              "type": "string",
              "enum": ["list", "count", "verify"],
              "default": "list"
            }
          },
          "required": ["category"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "check_immutable_law",
        "description": "Check if code violates immutable laws",
        "parameters": {
          "type": "object",
          "properties": {
            "law_id": {
              "type": "string",
              "enum": ["USR-OVER-ETC", "NO-MKDIR-IN-VAR", "MANAGED-SELINUX", "BOUND-IMAGES", "PACKAGES-MD-SSOT"]
            },
            "file_path": {"type": "string"}
          },
          "required": ["law_id", "file_path"]
        }
      }
    }
  ]
}
```

### Function Implementation Example

```python
import json
import subprocess

def analyze_build_log(log_path: str, error_type: str = "all") -> dict:
    """Analyze MiOS build log for errors"""
    with open(log_path) as f:
        content = f.read()

    errors = []
    if error_type in ["all", "dnf"]:
        # Parse DNF errors
        dnf_errors = [line for line in content.split('\n') if 'Error:' in line and 'dnf' in line.lower()]
        errors.extend(dnf_errors)

    if error_type in ["all", "systemd"]:
        # Parse systemd errors
        systemd_errors = [line for line in content.split('\n') if 'systemd' in line.lower() and 'fail' in line.lower()]
        errors.extend(systemd_errors)

    return {
        "total_errors": len(errors),
        "errors": errors[:10],  # Limit to first 10
        "log_path": log_path
    }

# OpenAI API usage
response = client.chat.completions.create(
    model="llama3.1:8b",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "Analyze the latest build log"}
    ],
    tools=tools,
    tool_choice="auto"
)

# Handle function call
if response.choices[0].message.tool_calls:
    tool_call = response.choices[0].message.tool_calls[0]
    function_name = tool_call.function.name
    function_args = json.loads(tool_call.function.arguments)

    if function_name == "analyze_build_log":
        result = analyze_build_log(**function_args)
        print(json.dumps(result, indent=2))
```

---

## RAG (Retrieval-Augmented Generation)

### Knowledge Sources (Priority Order)

1. **Wiki (PRIMARY)** - https://github.com/Kabuki94/MiOS-bootstrap/wiki
   - Auto-synced every build
   - Latest documentation, research, build logs
   - Check first before using local files

2. **INDEX.md** - AI agent hub, immutable laws, conventions

3. **KNOWLEDGE-BASE.md** - This file (consolidated knowledge)

4. **specs/** - Architectural specifications (43 documents)

5. **Build logs** - `/var/log/mios/`, `/usr/lib/mios/logs/build.log`

6. **Memory system** - `.ai/foundation/memories/journal.md`

### RAG Configuration (rag-config.yaml)

```yaml
# artifacts/ai-rag/rag-manifest.yaml
embedding:
  provider: ollama
  model: nomic-embed-text
  endpoint: http://localhost:11434
  dimensions: 768

vector_store:
  type: chroma  # or faiss, qdrant
  persist_directory: /var/lib/mios/rag/chroma
  collection_name: mios_knowledge

chunking:
  strategy: semantic
  chunk_size: 512
  chunk_overlap: 50

retrieval:
  top_k: 5
  score_threshold: 0.7
  reranking: true

sources:
  - path: /mios/INDEX.md
    weight: 1.0
    type: markdown
  - path: /mios/.ai/KNOWLEDGE-BASE.md
    weight: 0.9
    type: markdown
  - path: /mios/specs/
    weight: 0.8
    type: directory
    recursive: true
  - path: /usr/lib/mios/logs/build.log
    weight: 0.6
    type: log
```

### RAG Query Pattern

```python
from langchain.vectorstores import Chroma
from langchain.embeddings import OllamaEmbeddings
from langchain.llms import Ollama

# Initialize
embeddings = OllamaEmbeddings(
    model="nomic-embed-text",
    base_url="http://localhost:11434"
)

vectorstore = Chroma(
    persist_directory="/var/lib/mios/rag/chroma",
    embedding_function=embeddings,
    collection_name="mios_knowledge"
)

llm = Ollama(
    model="llama3.1:8b",
    base_url="http://localhost:11434"
)

# Query
query = "How do I add a new package to PACKAGES.md?"
docs = vectorstore.similarity_search(query, k=5)

# Generate response
context = "\n\n".join([doc.page_content for doc in docs])
prompt = f"""Context from MiOS knowledge base:
{context}

Question: {query}

Answer based on the context above:"""

response = llm(prompt)
print(response)
```

---

## Memory System

### Episodic Memory (Journal)

**Location:** `.ai/foundation/memories/journal.md`

**Format:**
```markdown
## 2026-04-28

### [10:30 UTC] Build Error: NVIDIA kmod mismatch
- Symptom: nvidia-smi fails with version mismatch
- Cause: ucore kernel update without matching kmod
- Fix: Pin NVIDIA kmod version to kernel version
- Script: automation/11-hardware.sh:45
```

### Semantic Memory (Long-term)

**Location:** `.ai/foundation/memory/*.md`

**Files:**
- `agent-bootstrap.md` - Agent initialization procedures
- `MEMORY.md` - Core knowledge retention
- `project_no_gcp.md` - Project-specific context

### Working Memory (Temporary)

**Location:** `.ai/foundation/shared-tmp/`

**Purpose:** Transient cross-agent data, cleared periodically

---

## Prompt Templates

### System Prompt (Base)

```markdown
You are an AI assistant for MiOS, an immutable cloud-native workstation OS.

**Core Principles:**
1. Wiki-first: Always check https://github.com/Kabuki94/MiOS-bootstrap/wiki for latest docs
2. Immutable laws: Never violate the 10 architecture rules (USR-OVER-ETC, NO-MKDIR-IN-VAR, etc.)
3. FOSS-first: Prioritize open-source AI APIs (Ollama, llama.cpp, LocalAI, vLLM)
4. FHS compliance: All files in correct Linux filesystem locations
5. Pattern-based: Follow established script patterns (source common.sh, use log() functions)

**Knowledge Sources (Priority):**
1. Wiki (https://github.com/Kabuki94/MiOS-bootstrap/wiki) - CHECK FIRST
2. INDEX.md - Immutable laws, conventions
3. KNOWLEDGE-BASE.md - Consolidated knowledge
4. specs/ - Architecture specifications
5. Build logs - /var/log/mios/

**Available Tools:**
- analyze_build_log: Parse build logs for errors
- validate_script: Check script syntax and patterns
- query_packages: Search PACKAGES.md
- check_immutable_law: Verify architecture compliance

**Operational Patterns:**
- All scripts MUST source automation/lib/common.sh
- All package installation via PACKAGES.md using install_packages()
- All errors use die(), warnings use warn(), info uses log()
- Never write to /etc/ at build time (use /usr/lib/)
- Never mkdir in /var/ (use tmpfiles.d)
```

### Code Review Prompt

```markdown
Review this MiOS script for:

1. **Immutable Law Violations:**
   - USR-OVER-ETC: Writing to /etc/ at build time?
   - NO-MKDIR-IN-VAR: Creating /var/ directories?
   - PACKAGES-MD-SSOT: Bypassing PACKAGES.md?

2. **Pattern Compliance:**
   - Sources automation/lib/common.sh?
   - Uses log()/warn()/die() functions?
   - Has proper error handling (set -euo pipefail)?
   - Follows standard template?

3. **Security:**
   - No hardcoded secrets?
   - Proper credential masking?
   - Safe file permissions?

4. **Best Practices:**
   - Quoted variables?
   - Command existence checks?
   - Validation after critical operations?

Provide specific line-by-line feedback.
```

### Build Analysis Prompt

```markdown
Analyze this MiOS build log:

1. **Error Summary:**
   - Total errors/warnings
   - Categorize by type (DNF, systemd, SELinux, bootc)

2. **Failed Scripts:**
   - Which numbered scripts failed?
   - Root cause analysis

3. **Recommendations:**
   - How to fix each error
   - Which scripts to modify
   - Which packages to add/remove

4. **Success Rate:**
   - Scripts succeeded/failed
   - Build duration
   - Critical vs non-critical failures

Use analyze_build_log function for detailed parsing.
```

---

## Testing & Validation

### Smoke Tests

```bash
# Container smoke test
podman run --rm localhost/mios:latest /bin/bash -c "
  bootc --version &&
  mios --version &&
  test -f /usr/share/mios/PACKAGES.md
"

# Greenboot health checks
ls /usr/lib/greenboot/check/required.d/*.sh
ls /usr/lib/greenboot/check/wanted.d/*.sh

# Evals
./evals/smoke-test.sh localhost/mios:latest
./evals/qemu-boot-check.sh
```

### Validation Commands

```bash
# Script syntax
bash -n automation/*.sh

# Containerfile lint
podman build --no-cache -t test .
podman run --rm test bootc container lint

# Package queries
grep -A999 '```packages-gnome' usr/share/mios/PACKAGES.md | head -20

# Immutable law checks
grep -r 'mkdir /var/' automation/  # Should be empty
grep -r 'dnf install' automation/ | grep -v PACKAGES  # Should be minimal
```

---

## API Integration Examples

### Ollama (Recommended)

```python
import requests

def chat_with_mios_context(question: str) -> str:
    """Chat with Ollama using MiOS context"""

    # Load system prompt
    with open('/mios/.ai/system-prompt.md') as f:
        system_prompt = f.read()

    # Load knowledge base
    with open('/mios/.ai/KNOWLEDGE-BASE.md') as f:
        knowledge = f.read()

    # API call
    response = requests.post(
        "http://localhost:11434/v1/chat/completions",
        json={
            "model": "llama3.1:8b",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Context:\n{knowledge[:4000]}\n\nQuestion: {question}"}
            ],
            "temperature": 0.7,
            "max_tokens": 2048
        }
    )

    return response.json()['choices'][0]['message']['content']

# Usage
answer = chat_with_mios_context("How do I add a new systemd service?")
print(answer)
```

### llama.cpp

```python
from llama_cpp import Llama

# Load model
llm = Llama(
    model_path="/var/lib/mios/models/llama-3.1-8b-instruct.Q4_K_M.gguf",
    n_ctx=8192,
    n_gpu_layers=-1  # Offload all layers to GPU
)

# Load context
with open('/mios/.ai/KNOWLEDGE-BASE.md') as f:
    knowledge = f.read()

# Generate
output = llm(
    f"Context: {knowledge[:4000]}\n\nQuestion: Explain the build pipeline",
    max_tokens=1024,
    temperature=0.7,
    stop=["###", "\n\n\n"]
)

print(output['choices'][0]['text'])
```

### LocalAI

```python
from openai import OpenAI

# LocalAI uses OpenAI client
client = OpenAI(
    base_url="http://localhost:8080/v1",
    api_key="not-needed"  # LocalAI doesn't require key
)

# Load system prompt
with open('/mios/.ai/system-prompt.md') as f:
    system_prompt = f.read()

# Chat completion
response = client.chat.completions.create(
    model="llama-3.1-8b-instruct",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "What are the immutable laws?"}
    ],
    temperature=0.7,
    max_tokens=1024
)

print(response.choices[0].message.content)
```

### vLLM

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"
)

# Streaming response
stream = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
    messages=[
        {"role": "system", "content": "You are MiOS AI assistant"},
        {"role": "user", "content": "Explain bootc"}
    ],
    stream=True,
    temperature=0.7
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end='', flush=True)
```

---

## Quick Reference

### Essential Commands

```bash
# Build
just build                    # Full build
mios build                    # Native build command
build-mios.sh                 # Fedora Server ignition

# Validate
bash -n script.sh             # Syntax check
bootc container lint          # Image validation
./evals/smoke-test.sh         # Smoke test

# Query
grep -A10 '```packages-' usr/share/mios/PACKAGES.md  # List packages
mios status                   # System status
bootc status                  # Bootc status

# AI
curl http://localhost:11434/v1/models  # List Ollama models
ollama pull llama3.1:8b       # Download model
```

### File Locations

```bash
# Build
/mios/Containerfile                    # Build definition
/mios/automation/build.sh              # Master orchestrator
/usr/share/mios/PACKAGES.md            # Package SSOT

# Config
~/.config/mios/                        # User configuration
/etc/mios/                             # System configuration
/usr/lib/systemd/system/               # Systemd units

# Logs
/var/log/mios/                         # Runtime logs
/usr/lib/mios/logs/build.log           # Build log

# AI
/mios/.ai/KNOWLEDGE-BASE.md            # This file
/mios/.ai/context.json                 # Unified context
/mios/.ai/tools.json                   # Function definitions
```

### Environment Setup

```bash
# User space is automatically initialized by build-mios.sh
# For manual initialization (if needed), use:
# just init-user-space

# Load environment
source /usr/share/mios/tools/load-user-env.sh

# AI environment
export MIOS_AI_ENDPOINT="http://localhost:11434"
export MIOS_AI_MODEL="llama3.1:8b"
```

---

## Changelog

### v2.0.0 (2026-04-28)

**Major consolidation:**
- Merged AI-KNOWLEDGE-CONSOLIDATED.md (713 lines)
- Merged AI-KNOWLEDGE-SUMMARY.md (~150 lines)
- Merged HISTORICAL-KNOWLEDGE-COMPRESSED.md (~300 lines)
- Merged AI-AGENT-GUIDE.md (289 lines)
- Added FOSS AI API patterns (Ollama, llama.cpp, LocalAI, vLLM)
- Added function calling examples
- Added RAG configuration
- Added API integration examples
- Added memory system documentation
- Added prompt templates
- **Total consolidation:** ~1,500 lines → 1 file

**Target audience:**
- Open-source AI APIs (Ollama, llama.cpp, LocalAI, vLLM)
- AI agents (LangChain, LlamaIndex)
- OpenAI-compatible clients
- RAG systems

**Format:**
- OpenAI Chat Completions API compatible
- Vendor-neutral, FOSS-first
- Self-contained, no external dependencies

---

**Generated:** 2026-04-28
**Version:** 2.0.0
**License:** Personal Property - MiOS-DEV
**Maintained by:** MiOS-DEV
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
