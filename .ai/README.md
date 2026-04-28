# MiOS AI Environment

**Version:** 2.0.0
**Generated:** 2026-04-28
**Target:** FOSS AI APIs (Ollama, llama.cpp, LocalAI, vLLM)
**Format:** OpenAI-compatible

---

## Overview

This directory contains **consolidated, FOSS-optimized AI integration files** for MiOS. All files follow OpenAI-compatible formatting and prioritize open-source AI APIs.

### Design Principles

1. **FOSS-First**: Vendor-neutral, prioritizes open-source AI APIs
2. **Consolidated**: All knowledge in single KNOWLEDGE-BASE.md (29KB)
3. **API-Compatible**: OpenAI Chat Completions API format
4. **Self-Contained**: No external dependencies
5. **Well-Documented**: Complete examples and patterns

---

## File Structure

```
.ai/
├── README.md                  # This file
├── KNOWLEDGE-BASE.md          # **NEW** Consolidated knowledge (all AI knowledge)
├── system-prompt.md           # System prompt for AI agents (updated v2.0.0)
├── context.json               # Unified project context (OpenAI compatible)
├── tools.json                 # Function calling definitions (OpenAI format)
├── prompt-templates.json      # Reusable prompt templates
├── variables.json             # Variable mappings (@track: system)
└── foundation/                # Memory system
    ├── memories/              # Episodic memory (journal.md)
    └── memory/                # Semantic memory
```

### Legacy Files Removed

These files were consolidated into `KNOWLEDGE-BASE.md`:
- ~~AI-KNOWLEDGE-CONSOLIDATED.md~~ (713 lines) → KNOWLEDGE-BASE.md
- ~~AI-KNOWLEDGE-SUMMARY.md~~ (~150 lines) → KNOWLEDGE-BASE.md
- ~~HISTORICAL-KNOWLEDGE-COMPRESSED.md~~ (~300 lines) → KNOWLEDGE-BASE.md
- ~~AI-AGENT-GUIDE.md~~ (289 lines) → KNOWLEDGE-BASE.md
- ~~AI-ENVIRONMENT-FLATTENING.md~~ → README.md (this file)

**Total consolidation:** ~1,500 lines → 29KB single file

---

## File Descriptions

### 1. context.json

**Purpose:** Unified project context in OpenAI-compatible JSON format

**Schema:**
```json
{
  "project": {...},
  "api_compatibility": {...},
  "knowledge_base": {...},
  "function_tools": {...},
  "memory_system": {...},
  "immutable_laws": [...],
  "build_pipeline": {...}
}
```

**Use Cases:**
- AI agent initialization
- Context loading for chat sessions
- Metadata retrieval
- API configuration

**Load with:**
```python
import json
with open('.ai/context.json') as f:
    context = json.load(f)
```

---

### 2. system-prompt.md

**Purpose:** System prompt for AI agents (markdown format)

**Sections:**
- Project Identity
- Core Principles (Wiki-first, immutable laws, FHS compliance)
- Knowledge Sources (prioritized)
- Build Pipeline
- AI API Integration
- Memory System
- Operational Patterns

**Use Cases:**
- System message in chat completions
- Agent initialization prompt
- Context injection

**OpenAI API Example:**
```python
with open('.ai/system-prompt.md') as f:
    system_prompt = f.read()

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "How do I build MiOS?"}
    ]
)
```

---

### 3. rag-config.yaml

**Purpose:** RAG (Retrieval-Augmented Generation) configuration

**Sections:**
- Live Documentation (Wiki URLs)
- Knowledge Sources (weighted by importance)
- Embedding Strategy (chunk size, model, dimensions)
- Retrieval Strategy (top-k, reranking, filters)
- FOSS AI API Configurations (Ollama, llama.cpp, LocalAI, vLLM)
- Function Calling
- Vector Store Configuration

**Use Cases:**
- RAG pipeline setup
- Embedding configuration
- API endpoint configuration
- Knowledge source prioritization

**Load with:**
```python
import yaml
with open('.ai/rag-config.yaml') as f:
    config = yaml.safe_load(f)
```

---

### 4. tools.json

**Purpose:** OpenAI-compatible function calling definitions

**Schema:** OpenAPI 3.1.0

**Available Functions:**
- `mios_update` - System updates via bootc
- `mios_status` - System status and health
- `mios_vfio_check` - VFIO GPU passthrough readiness
- `mios_vfio_toggle` - PCIe device binding for VMs
- `mios_package_search` - Search PACKAGES.md SSOT
- `mios_build` - Trigger image build

**Use Cases:**
- OpenAI function calling
- Ollama tools
- LangChain tools
- LlamaIndex tools

**OpenAI API Example:**
```python
import json
with open('.ai/tools.json') as f:
    tools = json.load(f)['tools']

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Check for updates"}],
    functions=tools,
    function_call="auto"
)
```

---

### 5. knowledge.txt

**Purpose:** Plain text unified knowledge base

**Format:** Structured plain text (maximum API compatibility)

**Sections:**
- System Identity
- Core Principles
- Technology Stack
- Build Pipeline
- Package Management
- AI API Integration
- Knowledge Sources
- Memory System
- Protected Files
- Operational Patterns
- Quick Start
- Common Tasks
- Debugging

**Use Cases:**
- Plain text ingestion for any API
- Fallback when JSON/YAML not supported
- Documentation generation
- Context injection

**Load with:**
```python
with open('.ai/knowledge.txt') as f:
    knowledge = f.read()
```

---

### 6. prompt-templates.json

**Purpose:** Reusable prompt templates for different scenarios

**Templates:**
- `system_init` - General AI assistant initialization
- `build_assistant` - Build operations assistance
- `package_manager` - Package management
- `security_auditor` - Security auditing
- `gpu_specialist` - GPU configuration
- `debug_helper` - Debugging assistance
- `code_reviewer` - Code review

**Use Cases:**
- Role-based AI agents
- Specialized assistants
- Conversation starters
- Function calling examples

**OpenAI API Example:**
```python
import json
with open('.ai/prompt-templates.json') as f:
    templates = json.load(f)

system_prompt = templates['templates']['build_assistant']['content']

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "How do I build an ISO?"}
    ]
)
```

---

## Usage Examples

### Example 1: OpenAI API

```python
import openai
import json

# Load context
with open('.ai/context.json') as f:
    context = json.load(f)

# Load system prompt
with open('.ai/system-prompt.md') as f:
    system_prompt = f.read()

# Load tools
with open('.ai/tools.json') as f:
    tools = json.load(f)['tools']

# Create chat completion
response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "Check if there are MiOS updates available"}
    ],
    functions=tools,
    function_call="auto"
)

print(response.choices[0].message)
```

### Example 2: Ollama

```python
import requests
import json

# Load system prompt
with open('.ai/system-prompt.md') as f:
    system_prompt = f.read()

# Ollama API call
response = requests.post(
    'http://localhost:11434/api/generate',
    json={
        'model': 'llama3.1:8b',
        'prompt': system_prompt + '\n\nUser: How do I build MiOS?\nAssistant:',
        'stream': False
    }
)

print(response.json()['response'])
```

### Example 3: LangChain

```python
from langchain.chat_models import ChatOpenAI
from langchain.prompts import ChatPromptTemplate
from langchain.schema import SystemMessage, HumanMessage

# Load system prompt
with open('.ai/system-prompt.md') as f:
    system_prompt = f.read()

# Create chat model
llm = ChatOpenAI(model="gpt-4", base_url="http://localhost:8080/v1")

# Create messages
messages = [
    SystemMessage(content=system_prompt),
    HumanMessage(content="How do I add a package to MiOS?")
]

# Get response
response = llm(messages)
print(response.content)
```

### Example 4: RAG with ChromaDB

```python
import chromadb
import yaml
from sentence_transformers import SentenceTransformer

# Load RAG config
with open('.ai/rag-config.yaml') as f:
    config = yaml.safe_load(f)

# Initialize embedding model
model_name = config['embeddings']['model']
model = SentenceTransformer(model_name)

# Initialize ChromaDB
client = chromadb.Client()
collection = client.create_collection(
    name=config['vector_store']['collection_name'],
    metadata={"hnsw:space": config['vector_store']['distance_metric']}
)

# Load and embed knowledge
with open('.ai/knowledge.txt') as f:
    knowledge = f.read()

# Chunk and embed (simplified)
chunks = knowledge.split('\n\n')
embeddings = model.encode(chunks)

# Add to vector store
collection.add(
    embeddings=embeddings.tolist(),
    documents=chunks,
    ids=[f"chunk_{i}" for i in range(len(chunks))]
)

# Query
query = "What are the immutable laws?"
query_embedding = model.encode([query])
results = collection.query(
    query_embeddings=query_embedding.tolist(),
    n_results=5
)

print(results)
```

---

## FOSS AI API Configuration

### Ollama

```yaml
endpoint: http://localhost:11434
models:
  - llama3.1:8b
  - codellama:13b
  - mistral:7b
context_window: 8192
```

### llama.cpp

```yaml
endpoint: http://localhost:8080
api_path: /v1/chat/completions
context_window: 4096
n_gpu_layers: -1  # all on GPU
```

### LocalAI

```yaml
endpoint: http://localhost:8080
api_path: /v1/chat/completions
embeddings_model: all-MiniLM-L6-v2
context_window: 8192
```

### vLLM

```yaml
endpoint: http://localhost:8000
model: meta-llama/Llama-3.1-8B-Instruct
tensor_parallel: 1
max_model_len: 8192
```

---

## Environment Variables

Set these in your environment or `.env` file:

```bash
# API Configuration
export MIOS_AI_KEY="your-api-key"
export MIOS_AI_MODEL="llama3.1:8b"
export MIOS_AI_ENDPOINT="http://localhost:8080/v1"
export MIOS_AI_TEMPERATURE="0.7"

# RAG Configuration
export MIOS_RAG_TOP_K="5"
export MIOS_RAG_SCORE_THRESHOLD="0.7"
export MIOS_EMBEDDING_MODEL="all-MiniLM-L6-v2"
```

---

## Integration Checklist

- [ ] Load `.ai/context.json` for project metadata
- [ ] Load `.ai/system-prompt.md` for system message
- [ ] Load `.ai/tools.json` for function calling
- [ ] Configure RAG using `.ai/rag-config.yaml`
- [ ] Set `MIOS_AI_*` environment variables
- [ ] Test with a simple query
- [ ] Validate function calling works
- [ ] Check Wiki for latest updates

---

## Migration from Old Structure

**Old Files → New Files:**

- `ai-context.json` → `.ai/context.json` (enhanced)
- `ai-tools/rag/rag-manifest.yaml` → `.ai/rag-config.yaml` (enhanced)
- `.well-known/ai-tools.json` → `.ai/tools.json` (enhanced with OpenAPI schema)
- `INDEX.md` + `AI-KNOWLEDGE-CONSOLIDATED.md` → `.ai/knowledge.txt` (flattened)
- Various AI prompts → `.ai/prompt-templates.json` (consolidated)

**Legacy Files (Preserved):**

- `INDEX.md` - Architecture laws (still canonical)
- `AI-KNOWLEDGE-CONSOLIDATED.md` - Current knowledge (still canonical)
- `HISTORICAL-KNOWLEDGE-COMPRESSED.md` - Historical context (still canonical)
- `.ai/foundation/memories/` - Semantic memory (still active)

---

## API Compatibility Matrix

| API | context.json | system-prompt.md | tools.json | rag-config.yaml | knowledge.txt |
|-----|-------------|------------------|------------|-----------------|---------------|
| OpenAI | ✅ | ✅ | ✅ | ⚠️ Manual | ✅ |
| Ollama | ✅ | ✅ | ✅ | ✅ | ✅ |
| llama.cpp | ✅ | ✅ | ✅ | ✅ | ✅ |
| LocalAI | ✅ | ✅ | ✅ | ✅ | ✅ |
| vLLM | ✅ | ✅ | ✅ | ✅ | ✅ |
| Anthropic | ✅ | ✅ | ⚠️ Different format | ⚠️ Manual | ✅ |
| Gemini | ✅ | ✅ | ⚠️ Different format | ⚠️ Manual | ✅ |
| LangChain | ✅ | ✅ | ✅ | ✅ | ✅ |
| LlamaIndex | ✅ | ✅ | ✅ | ✅ | ✅ |

✅ = Fully compatible
⚠️ = Requires adaptation

---

## Troubleshooting

### Issue: AI not finding knowledge

**Solution:** Check that `.ai/knowledge.txt` and `.ai/context.json` are loaded

### Issue: Function calling not working

**Solution:** Verify `.ai/tools.json` is properly formatted and loaded

### Issue: RAG returning irrelevant results

**Solution:** Adjust `top_k` and `score_threshold` in `.ai/rag-config.yaml`

### Issue: API endpoint not responding

**Solution:** Check `MIOS_AI_ENDPOINT` environment variable and ensure API is running

---

## Contributing

When updating AI environment files:

1. Maintain OpenAI API compatibility
2. Update version numbers and timestamps
3. Test with multiple FOSS AI APIs
4. Validate JSON/YAML schemas
5. Update this README

---

## License

Personal Property - MiOS-DEV

---

**Generated:** 2026-04-28T03:49:00Z
**Version:** 1.0.0
**Repository:** https://github.com/Kabuki94/MiOS-bootstrap
