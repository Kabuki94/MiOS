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

def generate_unified_knowledge(output_file="artifacts/repo-rag-snapshot.json.gz"):
    print(f"🧠 Generating Unified Knowledge Base: {output_file}...")
    
    ignore_dirs = {".git", ".venv", "__pycache__", "node_modules"} # removed 'output' to check for logs
    snapshot = {
        "metadata": {
            "project": "MiOS",
            "timestamp": datetime.now().isoformat(),
            "scope": "Full Repository Snapshot (including dotfiles and build logs)",
            "rag_format_version": "1.1"
        },
        "knowledge_nodes": [],
        "build_artifacts": {
            "last_build_logs": []
        }
    }

    # 1. Capture Repository Snapshot
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        
        for file in files:
            # Skip the output file itself to avoid recursion
            if file == os.path.basename(output_file) or file == "repo-rag-snapshot.json":
                continue
                
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, start=os.getcwd())
            
            # Identify file category
            category = "other"
            if rel_path.startswith("specs/"): category = "documentation"
            elif rel_path.startswith("automation/"): category = "automation"
            elif rel_path.startswith(""): category = "configuration"
            elif rel_path.startswith("evals/"): category = "validation"
            elif file.startswith("."): category = "environment"
            elif file.endswith(".md"): category = "documentation"
            elif file.endswith((".sh", ".py", ".ps1", ".toml", "Justfile", "Containerfile")): category = "source"

            try:
                # Capture text-based files
                if file.endswith((".md", ".json", ".sh", ".py", ".ps1", ".toml", ".yaml", ".yml", ".conf", ".txt", ".log", "Containerfile", "Justfile")) or file.startswith("."):
                    # Optimization: only read small/medium files for the snapshot to keep UKB manageable
                    if os.path.getsize(file_path) > 1024 * 1024: # Skip > 1MB in general snapshot
                         continue

                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    # Redact secrets
                    if category in ["environment", "configuration", "source"] or file.endswith(".env"):
                        content = redact_secrets(content)

                    node = {
                        "path": rel_path,
                        "category": category,
                        "last_modified": datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat(),
                        "content": content
                    }
                    
                    # Special handling for build logs
                    if file.endswith(".log") and ("build" in file or "mios" in file):
                        snapshot["build_artifacts"]["last_build_logs"].append(node)
                    else:
                        snapshot["knowledge_nodes"].append(node)
            except Exception as e:
                print(f"⚠️ Could not process {rel_path}: {e}")

    # 2. Check for standard system build log locations (if running in a build container)
    sys_log_paths = ["/tmp/mios-build.log", "/var/log/mios-build.log", "/usr/lib/mios/logs/mios-build.log"]
    for lp in sys_log_paths:
        if os.path.exists(lp):
            try:
                with open(lp, 'r', encoding='utf-8', errors='ignore') as f:
                    log_content = f.read()
                snapshot["build_artifacts"]["last_build_logs"].append({
                    "path": lp,
                    "category": "build_log",
                    "last_modified": datetime.fromtimestamp(os.path.getmtime(lp)).isoformat(),
                    "content": log_content
                })
                print(f"📦 Artifacted system build log: {lp}")
            except:
                pass

    # Ensure artifacts directory exists
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with gzip.open(output_file, 'wt', encoding='utf-8') as f:
        json.dump(snapshot, f, indent=2)
    
    total_nodes = len(snapshot["knowledge_nodes"]) + len(snapshot["build_artifacts"]["last_build_logs"])
    print(f"✅ UKB generated with {total_nodes} nodes (including {len(snapshot['build_artifacts']['last_build_logs'])} build logs).")

if __name__ == "__main__":
    generate_unified_knowledge()
