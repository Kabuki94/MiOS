import os
import json
import re
import gzip
from datetime import datetime

def redact_secrets(content):
    """Redacts common secret patterns from content."""
    patterns = [
        (r'(?i)(api_key|secret|password|token|private_key)(\s*[:=]\s*)([^\s,]+)', r'\1\2[REDACTED]'),
        (r'AIza[0-9A-Za-z-_]{35}', '[REDACTED]'),  # Cloud API Keys
        (r'sk-[0-9A-Za-z]{48}', '[REDACTED]'),      # OpenAI Keys
    ]
    redacted = content
    for pattern, replacement in patterns:
        redacted = re.sub(pattern, replacement, redacted)
    return redacted

def parse_metadata(content, file_path):
    """Extracts structured metadata and patterns from content."""
    meta = {
        "title": os.path.basename(file_path),
        "summary": "",
        "patterns": [],
        "technologies": [],
        "logic_type": "unknown",
        "tags": []
    }
    
    # Extract markdown title
    title_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if title_match:
        meta["title"] = title_match.group(1).strip()

    # Extract json:knowledge block
    kb_match = re.search(r'```json:knowledge\s*\n(.*?)\n```', content, re.DOTALL)
    if kb_match:
        try:
            kb = json.loads(kb_match.group(1))
            meta.update(kb)
        except json.JSONDecodeError:
            pass

    # Basic pattern matching for technologies
    tech_keywords = ["bootc", "podman", "quadlet", "k3s", "ceph", "nvidia", "gnome", "selinux", "greenboot", "composefs", "wsl2"]
    for tech in tech_keywords:
        if tech in content.lower():
            if tech not in meta["technologies"]:
                meta["technologies"].append(tech)
    
    return meta

def generate_knowledge_hub_markdown(snapshot, output_path):
    """Generates a human-readable and AI-parsable Knowledge Hub index."""
    print(f"📄 Generating Navigable Knowledge Hub: {output_path}...")
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")
    
    hub_content = f"""<!-- 🌐 MiOS Artifact | Proprietor: MiOS-DEV | https://github.com/Kabuki94/MiOS-bootstrap -->
# 🧠 MiOS Unified Knowledge Hub

```json:knowledge
{{
  "summary": "Centralized index for all MiOS knowledge, context, and memories.",
  "logic_type": "index",
  "rag_compatible": true,
  "last_sync": "{timestamp}"
}}
```

## 📖 Overview
This hub provides a navigable map of the MiOS ecosystem, compacting research, memories, and engineering patterns into a unified structure.

> **AI AGENT HINT:** Use this page to discover deep context paths. Structured JSON context is available at `/usr/share/mios/knowledge/mios-knowledge-graph.json`.

---

## 🏛️ Knowledge Categories

"""
    
    categories = {
        "core_foundation": ("🧱 Core Foundation", "Architectural laws and fundamental blueprints."),
        "engineering": ("🔧 Engineering Patterns", "Implementation details and technical standards."),
        "history": ("📜 Historical Context", "Journals, changelogs, and decision records."),
        "automation": ("🤖 Automation Logic", "Build scripts and deployment orchestration."),
        "validation": ("✅ Validation & Evals", "Health checks and smoke tests."),
        "research": ("🔬 Research & Status", "Upstream analysis and upcoming features.")
    }
    
    for cat_key, (cat_name, cat_desc) in categories.items():
        hub_content += f"### {cat_name}\n*{cat_desc}*\n\n"
        nodes = [n for n in snapshot["knowledge_nodes"] if n["category"] == cat_key]
        if nodes:
            for node in nodes:
                path = node["path"]
                title = node["metadata"]["title"]
                # Create a GitHub-friendly link (strips .md for Wiki or uses full path)
                link = path.replace(".md", "")
                hub_content += f"- [{title}]({link})\n"
        else:
            hub_content += "- *No entries recorded.*\n"
        hub_content += "\n"

    hub_content += """---

## 🤖 FOSS AI Native Discovery
MiOS is designed for native parsing by local FOSS AI APIs.

### Parsing Instructions
1. **Context Ingestion**: Local LLMs should prioritize `usr/share/mios/knowledge/mios-knowledge-graph.json`.
2. **Episodic Memory**: The human-readable journal is at `specs/memory/journal.md`, backed by the JSONL stream at `var/lib/mios/memory/journal/v1.jsonl`.
3. **Artifact Mapping**: All build-time artifacts and repository snapshots are mapped to standard Linux paths in `/var/lib/mios/`.

### Supported APIs
- **Ollama**: Native JSON/Markdown ingestion.
- **llama.cpp**: High-fidelity RAG via structured manifests.
- **LocalAI**: OpenAI-compatible endpoint for unified tool use.

---
### ⚖️ Legal & Source Reference
- **Copyright:** (c) 2026 MiOS-DEV
- **Status:** Personal Property / Private Infrastructure
- **Project Repository:** [Kabuki94/MiOS-bootstrap](https://github.com/Kabuki94/MiOS-bootstrap)
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 MiOS-DEV -->
"""

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(hub_content)

def generate_unified_knowledge(output_file="artifacts/repo-rag-snapshot.json.gz", hub_file="specs/Knowledge-Hub.md"):
    print(f"🧠 Flattening Historical Knowledge into UKB: {output_file}...")
    
    ignore_dirs = {".git", ".venv", "__pycache__", "node_modules", "artifacts", "output"}
    snapshot = {
        "metadata": {
            "project": "MiOS",
            "timestamp": datetime.now().isoformat(),
            "scope": "Flattened Historical & Semantic Knowledge",
            "rag_format_version": "2.0",
            "foss_compliant": True,
            "ai_native": True
        },
        "semantic_index": {
            "core_blueprints": [],
            "engineering_patterns": [],
            "historical_context": [],
            "automation_logic": [],
            "validation_suites": []
        },
        "knowledge_nodes": []
    }

    # 1. Capture and Flatten Repository Knowledge
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, start=os.getcwd())
            
            # Skip non-text files and large files
            if not file.endswith((".md", ".json", ".sh", ".py", ".ps1", ".toml", ".yaml", ".yml", ".conf", ".txt", ".log", "Containerfile", "Justfile")) and not file.startswith("."):
                continue
            
            if os.path.getsize(file_path) > 1024 * 1024:
                continue

            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                content = redact_secrets(content)
                meta = parse_metadata(content, rel_path)
                
                # Determine category and index
                category = "other"
                index_key = None
                
                if rel_path.startswith("specs/core/"): 
                    category = "core_foundation"
                    index_key = "core_blueprints"
                elif rel_path.startswith("specs/engineering/"): 
                    category = "engineering"
                    index_key = "engineering_patterns"
                elif rel_path.startswith("specs/memory/") or rel_path.startswith("specs/changelogs/") or rel_path.startswith("specs/audit/"):
                    category = "history"
                    index_key = "historical_context"
                elif rel_path.startswith("automation/"): 
                    category = "automation"
                    index_key = "automation_logic"
                elif rel_path.startswith("evals/"): 
                    category = "validation"
                    index_key = "validation_suites"
                elif rel_path.startswith("specs/knowledge/"):
                    category = "research"
                    index_key = "engineering_patterns"
                
                node = {
                    "path": rel_path,
                    "category": category,
                    "metadata": meta,
                    "content": content
                }
                
                snapshot["knowledge_nodes"].append(node)
                if index_key:
                    snapshot["semantic_index"][index_key].append({
                        "path": rel_path,
                        "title": meta["title"],
                        "technologies": meta["technologies"]
                    })

            except Exception as e:
                print(f"⚠️ Could not process {rel_path}: {e}")

    # Ensure artifacts directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    # Save gzipped JSON
    with gzip.open(output_file, 'wt', encoding='utf-8') as f:
        json.dump(snapshot, f, indent=2)
    
    print(f"✅ Flattened UKB generated with {len(snapshot['knowledge_nodes'])} semantic nodes.")
    
    # Generate human-readable Hub
    generate_knowledge_hub_markdown(snapshot, hub_file)

if __name__ == "__main__":
    generate_unified_knowledge()
