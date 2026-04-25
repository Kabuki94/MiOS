import os
import json
import re
from datetime import datetime

def parse_markdown_metadata(content):
    """Simple parser to extract title and metadata from Markdown."""
    title_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else "Untitled"
    
    # Extract blockquotes/metadata lines like "> **Key:** Value"
    metadata = {}
    meta_matches = re.findall(r'^>\s+\*\*(.+?):\*\*\s+(.+)$', content, re.MULTILINE)
    for key, value in meta_matches:
        metadata[key.strip().lower().replace(" ", "_")] = value.strip()
    
    return title, metadata

def generate_json_manifest(target_dir, output_file):
    manifest = {
        "generated_at": datetime.now().isoformat(),
        "source_directory": target_dir,
        "entries": []
    }
    
    if not os.path.exists(target_dir):
        return

    for root, dirs, files in os.walk(target_dir):
        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, start=os.getcwd())
            
            entry = {
                "path": rel_path,
                "last_modified": datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat()
            }

            if file.endswith(".md"):
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                title, metadata = parse_markdown_metadata(content)
                entry.update({
                    "title": title,
                    "type": "documentation",
                    "metadata": metadata,
                    "content_preview": content[:500] + "..." if len(content) > 500 else content,
                    "full_content": content
                })
                manifest["entries"].append(entry)
            elif file.endswith(".json") and file != "manifest.json":
                with open(file_path, 'r', encoding='utf-8') as f:
                    try:
                        data = json.load(f)
                        entry.update({
                            "title": data.get("artifact_name", file),
                            "type": "artifact_metadata",
                            "structured_data": data
                        })
                        manifest["entries"].append(entry)
                    except json.JSONDecodeError:
                        continue
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2)
    print(f"Generated {output_file}")

if __name__ == "__main__":
    # Categories to manifest
    targets = [
        ("changelogs", "changelogs/manifest.json"),
        ("docs/knowledge", "docs/knowledge/manifest.json"),
        (".claude/memories", ".claude/memories/manifest.json"),
        (".ai-context", ".ai-context/manifest.json"),
        ("artifacts", "artifacts/manifest.json")
    ]
    
    for target_dir, output_file in targets:
        generate_json_manifest(target_dir, output_file)
