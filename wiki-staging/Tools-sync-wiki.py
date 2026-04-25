# sync-wiki.py
---

import os
import json
import shutil
from pathlib import Path

def prepare_wiki():
    hub_path = "ai-context.json"
    staging_dir = "wiki-staging"
    
    if not os.path.exists(hub_path):
        print("Error: ai-context.json not found.")
        return

    # 1. Setup Staging Area
    if os.path.exists(staging_dir):
        shutil.rmtree(staging_dir)
    os.makedirs(staging_dir)

    with open(hub_path, "r") as f:
        hub = json.load(f)

    # 2. Build Sidebar and Home content
    sidebar_content = "## 🌐 MiOS Navigation\n\n"
    home_content = f"# 🌐 MiOS Project Wiki (v{hub['version']})\n\n"
    home_content += "Welcome to the MiOS Knowledge Base. This wiki is automatically synchronized from the repository's AI-context manifests.\n\n"

    # 3. Process Manifests
    for category, manifest_path in hub["manifests"].items():
        if not os.path.exists(manifest_path):
            continue
            
        with open(manifest_path, "r") as f:
            data = json.load(f)
        
        category_title = category.replace("_", " ").title()
        sidebar_content += f"### {category_title}\n"
        home_content += f"## {category_title}\n"
        
        for entry in data["entries"]:
            # Flatten filename for Wiki (replace / with -)
            original_path = Path(entry["path"])
            wiki_filename = f"{category_title.replace(' ', '-')}-{original_path.name}"
            target_path = os.path.join(staging_dir, wiki_filename)
            
            # Use structured title if available, else filename
            page_title = entry.get("title", original_path.stem.replace("-", " ").title())
            
            # Copy and add metadata header to the Wiki page
            if "full_content" in entry:
                with open(target_path, "w") as wf:
                    wf.write(f"# {page_title}\n")
                    if entry.get("metadata"):
                        wf.write("> **Metadata:** " + ", ".join([f"{k}: {v}" for k, v in entry["metadata"].items()]) + "\n\n")
                    wf.write("---\n\n")
                    wf.write(entry["full_content"])
            
            link = f"[[{page_title}|{wiki_filename.replace('.md', '')}]]"
            sidebar_content += f"- {link}\n"
            home_content += f"- {link} — *Last updated: {entry['last_modified'][:10]}*\n"
        
        sidebar_content += "\n"
        home_content += "\n"

    # 4. Write Navigation Files
    with open(os.path.join(staging_dir, "_Sidebar.md"), "w") as f:
        f.write(sidebar_content)
    
    with open(os.path.join(staging_dir, "Home.md"), "w") as f:
        f.write(home_content)

    print(f"Wiki staging complete in '{staging_dir}/'")
    print("Next step: cd wiki-staging && git init && git remote add origin <wiki-url> && git push")

if __name__ == "__main__":
    prepare_wiki()
