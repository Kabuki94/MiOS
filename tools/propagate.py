#!/usr/bin/env python3
import os
import re
import tomllib
import argparse

# Configuration
REGISTRY_PATH = "config/registry.toml"
TRACK_MARKER = "@track:"
LINE_RE = re.compile(r'^(?P<content>.*?)#\s*@track:(?P<tag>\S+)\s*$')

# Matchers for the content part
# 1. Quoted value: [prefix][quote][value][quote][mid]
# Prefix captures everything up to the LAST assignment operator (=, :=, :-) or space.
CONTENT_RE_QUOTED = re.compile(r'^(?P<prefix>.*(?:[:]=|=|\s|[:]-))(?P<quote>["\'])(?P<value>.*?)(?P<quote2>(?P=quote))(?P<mid>\s*)$')
# 2. Unquoted value: [prefix][value][mid]
CONTENT_RE_UNQUOTED = re.compile(r'^(?P<prefix>.*(?:[:]=|=|\s|[:]-))(?P<value>\S+)(?P<mid>\s*)$')

MAX_FILE_SIZE = 5 * 1024 * 1024

def propagate(dry_run=False, verbose=False):
    if not os.path.exists(REGISTRY_PATH):
        print(f"Error: Registry not found at {REGISTRY_PATH}")
        return

    try:
        with open(REGISTRY_PATH, "rb") as f:
            registry = tomllib.load(f)
    except Exception as e:
        print(f"Error parsing registry: {e}")
        return

    tags = registry.get("tags", {})
    if not tags: return

    tag_map = {tag_id: str(data.get("value")) for tag_id, data in tags.items()}
    exclude_dirs = {'.git', '.venv', 'node_modules', 'bin', 'obj', 'output', 'artifacts', '__pycache__'}
    
    scan_count = 0
    update_count = 0

    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        for file in files:
            file_path = os.path.normpath(os.path.join(root, file))
            if file_path == os.path.normpath(REGISTRY_PATH): continue
            
            try:
                if os.path.getsize(file_path) > MAX_FILE_SIZE: continue
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
            except Exception: continue

            if TRACK_MARKER not in content: continue
            scan_count += 1
            if verbose: print(f"Processing: {file_path}")
            
            lines = content.splitlines(keepends=True)
            new_lines = []
            changed = False
            
            for line_idx, line in enumerate(lines):
                if TRACK_MARKER not in line:
                    new_lines.append(line)
                    continue
                
                raw_line = line.rstrip('\n\r')
                line_match = LINE_RE.match(raw_line)
                
                if line_match:
                    content_part = line_match.group('content')
                    tag_id = line_match.group('tag')
                    
                    if tag_id not in tag_map:
                        new_lines.append(line)
                        continue
                        
                    new_val = tag_map[tag_id]
                    
                    # Try quoted match first
                    match = CONTENT_RE_QUOTED.match(content_part)
                    if match:
                        prefix = match.group('prefix')
                        quote = match.group('quote')
                        old_val = match.group('value')
                        mid = match.group('mid')
                        
                        if old_val != new_val:
                            new_line = f"{prefix}{quote}{new_val}{quote}{mid}# @track:{tag_id}"
                            if line.endswith('\n'): new_line += '\n'
                            elif line.endswith('\r\n'): new_line += '\r\n'
                            new_lines.append(new_line)
                            print(f"[{tag_id}] {file_path}:{line_idx+1} -> {new_val} (quoted)")
                            changed = True
                        else:
                            new_lines.append(line)
                    else:
                        # Try unquoted match
                        match = CONTENT_RE_UNQUOTED.match(content_part)
                        if match:
                            prefix = match.group('prefix')
                            old_val = match.group('value')
                            mid = match.group('mid')
                            
                            if old_val != new_val:
                                new_line = f"{prefix}{new_val}{mid}# @track:{tag_id}"
                                if line.endswith('\n'): new_line += '\n'
                                elif line.endswith('\r\n'): new_line += '\r\n'
                                new_lines.append(new_line)
                                print(f"[{tag_id}] {file_path}:{line_idx+1} -> {new_val} (unquoted)")
                                changed = True
                            else:
                                new_lines.append(line)
                        else:
                            new_lines.append(line)
                else:
                    new_lines.append(line)

            if changed and not dry_run:
                try:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.writelines(new_lines)
                    update_count += 1
                except Exception as e:
                    print(f"Error writing {file_path}: {e}")

    print(f"Summary: Scanned {scan_count} files, updated {update_count} files.")

def main():
    parser = argparse.ArgumentParser(description="Propagate MiOS Global Registry variables.")
    parser.add_argument("--dry-run", action="store_true", help="Show changes without applying them.")
    parser.add_argument("--verbose", action="store_true", help="Print more info.")
    args = parser.parse_args()
    propagate(dry_run=args.dry_run, verbose=args.verbose)

if __name__ == "__main__":
    main()
