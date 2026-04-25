#!/usr/bin/env bash
set -euo pipefail

echo ">>> Bootstrapping Node.js (Long Term Support)..."
if! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo ">>> Installing @google/gemini-cli..."
sudo npm install -g @google/gemini-cli@latest

echo ">>> Preparing IDE Extension Inter-Process Communication context..."
cat << 'EOF_BASH' >> "$HOME/.bashrc"
if [! -f "$HOME/.gemini/.ide_setup_complete" ]; then
    echo "================================================================="
    echo "Gemini CLI Dev Container Initialization Protocol"
    echo "Target Infrastructure Project: mios-os"
    echo "================================================================="
    echo "To finalize native VSCodium integration, please run:"
    echo "1. gemini"
    echo "2. /ide install"
    echo "3. /ide enable"
    echo "================================================================="
    mkdir -p "$HOME/.gemini"
    touch "$HOME/.gemini/.ide_setup_complete"
fi
EOF_BASH
