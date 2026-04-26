import os
import re
import json
from datetime import datetime

def sync_wiki():
    print("📖 Syncing Wiki Documentation...")
    
    # 1. Update Scripts Index
    scripts_dir = "scripts"
    scripts_doc = "docs/engineering/2026-04-26-Artifact-ENG-002-Scripts-Index.md"
    
    knowledge_meta = {
        "summary": "Automated index of all MiOS automation scripts.",
        "logic_type": "automation",
        "tags": ["scripts", "automation", "index"],
        "generated_at": datetime.now().isoformat()
    }

    content = f"""# 📜 MiOS Scripts Index
> **Generated:** {datetime.now().isoformat()}
> **Status:** Automated Sync

```json:knowledge
{json.dumps(knowledge_meta, indent=2)}
```

This file provides a machine-readable and human-readable index of all automation scripts in the `scripts/` directory.

"""
    for script in sorted(os.listdir(scripts_dir)):
        if script.endswith(".sh"):
            path = os.path.join(scripts_dir, script)
            # Try to extract a description from the first few lines
            description = "No description available."
            try:
                with open(path, 'r') as f:
                    lines = f.readlines()
                    for line in lines:
                        clean_line = line.strip()
                        if clean_line.startswith("# ") and not clean_line.startswith("#!") and "===" not in clean_line:
                            description = clean_line[2:].strip()
                            if description:
                                break
            except:
                pass
            content += f"## `{script}`\n- **Path:** `{path}`\n- **Description:** {description}\n\n"

    os.makedirs(os.path.dirname(scripts_doc), exist_ok=True)
    with open(scripts_doc, 'w') as f:
        f.write(content)
    print(f"✅ Updated {scripts_doc}")

    # 2. Ensure Home.md reflects the latest snapshot
    home_doc = "docs/Home.md"
    if os.path.exists(home_doc):
        with open(home_doc, 'r') as f:
            home_content = f.read()
        
        home_knowledge = {
            "summary": "Central navigation hub for MiOS documentation.",
            "logic_type": "documentation",
            "tags": ["wiki", "home", "navigation"],
            "last_rag_sync": datetime.now().isoformat()
        }

        knowledge_block = f"```json:knowledge\n{json.dumps(home_knowledge, indent=2)}\n```"
        
        if "```json:knowledge" in home_content:
            home_content = re.sub(r"```json:knowledge.*?```", knowledge_block, home_content, flags=re.DOTALL)
        else:
            # Insert after the main title
            home_content = re.sub(r"(# .+?\n)", rf"\1\n{knowledge_block}\n", home_content, count=1)

        snapshot_line = f"**Latest RAG Snapshot:** `artifacts/repo-rag-snapshot.json` ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})"
        if "Latest RAG Snapshot:" in home_content:
            home_content = re.sub(r"\*\*Latest RAG Snapshot:\*\* .*", snapshot_line, home_content)
        else:
            home_content += f"\n\n---\n{snapshot_line}\n"
        
        with open(home_doc, 'w') as f:
            f.write(home_content)
        print(f"✅ Updated {home_doc}")

if __name__ == "__main__":
    sync_wiki()
