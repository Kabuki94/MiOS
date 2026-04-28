#!/usr/bin/env python3
import os
import re
import mimetypes

# Mapping of common emojis/Unicode symbols to ASCII equivalents
MAPPING = {
    "▶️": "[START]",
    "✅": "[OK]",
    "❌": "[FAIL]",
    "⚠️": "[WARN]",
    "🧠": "[MEM]",
    "🏗️": "[ENG]",
    "🔍": "[RES]",
    "🌱": "[SEED]",
    "🌐": "[NET]",
    "🎯": "[GOAL]",
    "📦": "[PKG]",
    "💻": "[TECH]",
    "📊": "[STAT]",
    "🔄": "[SYNC]",
    "🛠️": "[BUILD]",
    "🛡️": "[SEC]",
    "🔗": "[LINK]",
    "📚": "[DOC]",
    "📁": "[DIR]",
    "📂": "[DIR]",
    "📄": "[FILE]",
    "🔎": "[FIND]",
    "💡": "[TIP]",
    "🔧": "[TOOL]",
    "🏗": "[BUILD]",
    "🧹": "[CLEAN]",
    "🧼": "[CLEAN]",
    "🚀": "[READY]",
    "🏁": "[DONE]",
    "🆕": "[NEW]",
    "⚡": "[FAST]",
    "🔥": "[HOT]",
    "🔒": "[LOCK]",
    "🔓": "[OPEN]",
    "🔑": "[KEY]",
    "🗝": "[KEY]",
    "📜": "[LOG]",
    "📋": "[CLIP]",
    "📌": "[PIN]",
    "📍": "[PIN]",
    "📎": "[CLIP]",
    "📏": "[MEAS]",
    "📐": "[MEAS]",
    "🔋": "[BATT]",
    "🔌": "[PLUG]",
    "🖥️": "[PC]",
    "💻": "[PC]",
    "⌨️": "[KB]",
    "🖱️": "[MOUSE]",
    "🖨️": "[PRINT]",
    "🏃": "[RUN]",
    "📹": "[VIDEO]",
    "🎮": "[GAME]",
    "🕹️": "[JOY]",
    "🔊": "[SOUND]",
    "🔈": "[SOUND]",
    "🔉": "[SOUND]",
    "🔇": "[MUTE]",
    "📢": "[ANNC]",
    "📣": "[ANNC]",
    "🔔": "[BELL]",
    "🔕": "[QUIET]",
    "🎵": "[MUSIC]",
    "🎶": "[MUSIC]",
    "📻": "[RADIO]",
    "📱": "[PHONE]",
    "☎️": "[PHONE]",
    "📞": "[PHONE]",
    "📟": "[PHONE]",
    "📠": "[FAX]",
    "🔦": "[LIGHT]",
    "🕯️": "[LIGHT]",
    "🛒": "[SHOP]",
    "🚬": "[SMOKE]",
    "🚭": "[NO-SMOKE]",
    "🚩": "[FLAG]",
    "🏁": "[FLAGS]",
    "🎌": "[FLAG]",
    "🏴": "[FLAG]",
    "🏳️": "[FLAG]",
    "🏳": "[FLAG]",
    "✔": "[DONE]",
    "✓": "[OK]",
    "✗": "[FAIL]",
    "➕": "[+]",
    "➖": "[-]",
    "✖": "[X]",
    "÷": "[/]",
    "▶": "[RUN]",
    "⏵": "[RUN]",
    "⏩": "[FF]",
    "⏪": "[RW]",
    "🔼": "[UP]",
    "🔽": "[DOWN]",
    "⏭": "[NEXT]",
    "⏮": "[PREV]",
    "⏺": "[REC]",
    "⏏": "[EJECT]",
    "⏸": "[PAUSE]",
    "⏹": "[STOP]",
    "🔴": "[REC]",
    "⬛": "[STOP]",
    "⏸️": "[PAUSE]",
    "⭐": "*",
    "⚪": "o",
    "🚫": "[BLOCK]",
    "─": "-",
    "│": "|",
    "┌": "+",
    "┐": "+",
    "└": "+",
    "┘": "+",
    "├": "+",
    "┤": "+",
    "┬": "+",
    "┴": "+",
    "┼": "+",
    "═": "=",
    "║": "|",
    "╔": "+",
    "╗": "+",
    "╚": "+",
    "╝": "+",
    "╠": "+",
    "╣": "+",
    "╦": "+",
    "╩": "+",
    "╬": "+",
    "╒": "+",
    "╓": "+",
    "╕": "+",
    "╖": "+",
    "╘": "+",
    "╙": "+",
    "╛": "+",
    "╜": "+",
    "╞": "+",
    "╟": "+",
    "╡": "+",
    "╢": "+",
    "╤": "+",
    "╥": "+",
    "╧": "+",
    "╨": "+",
    "╪": "+",
    "╫": "+",
    "⋙": ">>",
    "⋘": "<<",
    "✴": "*",
    "──": "--",
    "—": "-",
    "…": "...",
    "✔️": "[OK]",
    "✖️": "[FAIL]",
    "❎": "[X]",
    "⛔": "[FAIL]",
    "🛑": "[FAIL]",
    "❗": "[!]",
    "❕": "!",
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
    # Skip the tool itself to preserve the MAPPING keys
    if os.path.basename(file_path) == "remove-emojis.py":
        return

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
