#!/usr/bin/env python3
import os
import re
import mimetypes

# Mapping of common emojis/Unicode symbols to ASCII equivalents
MAPPING = {
    "[START]": "[START]",
    "[OK]": "[OK]",
    "[FAIL]": "[FAIL]",
    "[WARN]": "[WARN]",
    "[WARN]": "[WARN]",
    "[MEM]": "[MEM]",
    "[ENG]": "[ENG]",
    "[RES]": "[RES]",
    "[SEED]": "[SEED]",
    "[NET]": "[NET]",
    "[GOAL]": "[GOAL]",
    "[PKG]": "[PKG]",
    "[TECH]": "[TECH]",
    "[STAT]": "[STAT]",
    "[SYNC]": "[SYNC]",
    "[BUILD]": "[BUILD]",
    "[SEC]": "[SEC]",
    "[LINK]": "[LINK]",
    "[DOC]": "[DOC]",
    "[DIR]": "[DIR]",
    "[DIR]": "[DIR]",
    "[FILE]": "[FILE]",
    "[FIND]": "[FIND]",
    "[TIP]": "[TIP]",
    "[TOOL]": "[TOOL]",
    "[BUILD]": "[BUILD]",
    "[CLEAN]": "[CLEAN]",
    "[CLEAN]": "[CLEAN]",
    "[READY]": "[READY]",
    "[DONE]": "[DONE]",
    "[NEW]": "[NEW]",
    "[FAST]": "[FAST]",
    "[HOT]": "[HOT]",
    "[LOCK]": "[LOCK]",
    "[OPEN]": "[OPEN]",
    "[KEY]": "[KEY]",
    "[KEY]": "[KEY]",
    "[LOG]": "[LOG]",
    "[CLIP]": "[CLIP]",
    "[PIN]": "[PIN]",
    "[PIN]": "[PIN]",
    "[CLIP]": "[CLIP]",
    "[MEAS]": "[MEAS]",
    "[MEAS]": "[MEAS]",
    "[BATT]": "[BATT]",
    "[PLUG]": "[PLUG]",
    "[PC]": "[PC]",
    "[PC]": "[PC]",
    "[KB]": "[KB]",
    "[MOUSE]": "[MOUSE]",
    "[PRINT]": "[PRINT]",
    "[RUN]": "[RUN]",
    "[VIDEO]": "[VIDEO]",
    "[GAME]": "[GAME]",
    "[JOY]": "[JOY]",
    "[SOUND]": "[SOUND]",
    "[SOUND]": "[SOUND]",
    "[SOUND]": "[SOUND]",
    "[MUTE]": "[MUTE]",
    "[ANNC]": "[ANNC]",
    "[ANNC]": "[ANNC]",
    "[BELL]": "[BELL]",
    "[QUIET]": "[QUIET]",
    "[MUSIC]": "[MUSIC]",
    "[MUSIC]": "[MUSIC]",
    "[RADIO]": "[RADIO]",
    "[PHONE]": "[PHONE]",
    "[PHONE]": "[PHONE]",
    "[PHONE]": "[PHONE]",
    "[PHONE]": "[PHONE]",
    "[FAX]": "[FAX]",
    "[BATT]": "[BATT]",
    "[PLUG]": "[PLUG]",
    "[TIP]": "[TIP]",
    "[LIGHT]": "[LIGHT]",
    "[LIGHT]": "[LIGHT]",
    "[CLEAN]": "[CLEAN]",
    "[SHOP]": "[SHOP]",
    "[SMOKE]": "[SMOKE]",
    "[NO-SMOKE]": "[NO-SMOKE]",
    "[FLAG]": "[FLAG]",
    "[FLAGS]": "[FLAGS]",
    "[FLAG]": "[FLAG]",
    "[FLAG]": "[FLAG]",
    "[FLAG]": "[FLAG]",
    "[FLAG]": "[FLAG]",
    "[DONE]": "[DONE]",
    "[FLAG]": "[FLAG]",
    "[FLAG]": "[FLAG]",
    "[OK]": "[OK]",
    "[FAIL]": "[FAIL]",
    "[+]": "[+]",
    "[-]": "[-]",
    "[X]": "[*]",
    "[/]": "[/]",
    "[OK]": "[OK]",
    "[X]": "[X]",
    "[RUN]": "[RUN]",
    "[RUN]": "[RUN]",
    "[FF]": "[FF]",
    "[RW]": "[RW]",
    "[UP]": "[UP]",
    "[DOWN]": "[DOWN]",
    "[NEXT]": "[NEXT]",
    "[PREV]": "[PREV]",
    "[REC]": "[REC]",
    "[EJECT]": "[EJECT]",
    "[PAUSE]": "[PAUSE]",
    "[STOP]": "[STOP]",
    "[REC]": "[REC]",
    "[STOP]": "[STOP]",
    "[PAUSE]": "[PAUSE]",
    "*": "*",
    "o": "o",
    "[BLOCK]": "[BLOCK]",
    "-": "-",
    "|": "|",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "=": "=",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "|": "|",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    "+": "+",
    ">>": ">>",
    "<<": "<<",
    "*": "*",
    "--": "--",
    "-": "-",
    "...": "...",
    "[OK]": "[OK]",
    "[FAIL]": "[FAIL]",
    "[X]": "[X]",
    "[FAIL]": "[FAIL]",
    "[FAIL]": "[FAIL]",
    "[!]": "[!]",
    "!": "!",
}

# Regex to find any non-ASCII character
NON_ASCII_RE = re.compile(r'[^\x00-\x7f]')

def is_binary(file_path):
    mime = mimetypes.guess_type(file_path)
    if mime[0] and (mime[0].startswith('text/') or mime[0] == 'application/json' or mime[0] == 'application/x-yaml'):
        return False
    
    # Heuristic for files without extension
    try:
        with open(file_path, 'rb') as f:
            chunk = f.read(1024)
            if b'\0' in chunk:
                return True
    except:
        return True
    return False

def remove_emojis_from_file(file_path):
    if is_binary(file_path):
        return

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception:
        # Fallback to reading as binary and decoding ignoring errors
        try:
            with open(file_path, 'rb') as f:
                content = f.read().decode('utf-8', errors='ignore')
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return

    original_content = content
    
    # First pass: direct replacements from mapping
    for emoji, replacement in MAPPING.items():
        content = content.replace(emoji, replacement)
    
    # Second pass: remove any remaining non-ASCII characters
    content = NON_ASCII_RE.sub('', content)
    
    if content != original_content:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Processed: {file_path}")
        except Exception as e:
            print(f"Error writing {file_path}: {e}")

def main():
    exclude_dirs = ['.git', '.venv', 'node_modules', 'bin', 'obj', 'output', 'artifacts']
    
    for root, dirs, files in os.walk('/mios'):
        # Filter out excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            file_path = os.path.join(root, file)
            remove_emojis_from_file(file_path)

if __name__ == "__main__":
    main()
