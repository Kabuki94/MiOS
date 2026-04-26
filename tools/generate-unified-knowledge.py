import os
import json
import re
from datetime import datetime

def redact_secrets(content):
    """Redacts common secret patterns from content."""
    patterns = [
        (r'(?i)(api_key|secret|password|token|private_key)(\s*[:=]\s*)([^\s,]+)', r'\1\2[REDACTED]'),
        (r'AIza[0-9A-Za-z-_]{35}', '[REDACTED]'),  # Google API Keys
        (r'sk-[0-9A-Za-z]{48}', '[REDACTED]'),      # OpenAI Keys
    ]
    redacted = content
    for pattern, replacement in patterns:
        redacted = re.sub(pattern, replacement, redacted)
    return redacted

def generate_unified_knowledge(output_file="artifacts/repo-rag-snapshot.json"):
    print(f"🧠 Generating Unified Knowledge Base: {output_file}...")
    
    ignore_dirs = {".git", ".venv", "output", "__pycache__", "node_modules"}
    snapshot = {
        "metadata": {
            "project": "MiOS",
            "timestamp": datetime.now().isoformat(),
            "scope": "Full Repository Snapshot (including dotfiles)",
            "rag_format_version": "1.0"
        },
        "knowledge_nodes": []
    }

    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        for file in files:
            # Skip the output file itself to avoid recursion
            if file == os.path.basename(output_file):
                continue
                
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, start=os.getcwd())
            
            # Identify file category
            category = "other"
            if rel_path.startswith("docs/"): category = "documentation"
            elif rel_path.startswith("scripts/"): category = "automation"
            elif rel_path.startswith("system_files/"): category = "configuration"
            elif rel_path.startswith("tests/"): category = "validation"
            elif file.startswith("."): category = "environment"
            elif file.endswith(".md"): category = "documentation"
            elif file.endswith((".sh", ".py", ".ps1", ".toml", "Justfile", "Containerfile")): category = "source"

            try:
                # We want to capture the content of text-based files
                if file.endswith((".md", ".json", ".sh", ".py", ".ps1", ".toml", ".yaml", ".yml", ".conf", ".txt", "Containerfile", "Justfile")) or file.startswith("."):
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    # Redact secrets from environment and config files
                    if category in ["environment", "configuration", "source"] or file.endswith(".env"):
                        content = redact_secrets(content)

                    node = {
                        "path": rel_path,
                        "category": category,
                        "last_modified": datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat(),
                        "content": content
                    }
                    snapshot["knowledge_nodes"].append(node)
            except Exception as e:
                print(f"⚠️ Could not process {rel_path}: {e}")

    # Ensure artifacts directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(snapshot, f, indent=2)
    
    print(f"✅ UKB generated with {len(snapshot['knowledge_nodes'])} nodes.")

if __name__ == "__main__":
    generate_unified_knowledge()
