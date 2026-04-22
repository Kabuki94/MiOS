# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for file in ~/.bashrc.d/*.bashrc ; do
		[ -r "$file" ] && . "$file"
	done
	unset file
fi

# ── CloudWS v0.1.8 ──────────────────────────────────────────────────
# Show system dashboard on interactive terminal open
if [[ $- == *i* ]]; then
    # Fastfetch with services dashboard
    if command -v fastfetch &>/dev/null; then
        fastfetch 2>/dev/null || true
    fi
    # Show cloudws --help hint on first open
    if [ ! -f "$HOME/.cloudws-welcomed" ]; then
        echo ""
        echo "  Type 'cloudws --help' for available commands."
        echo ""
        touch "$HOME/.cloudws-welcomed" 2>/dev/null || true
    fi
fi
