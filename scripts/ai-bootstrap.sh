#!/bin/bash
# MiOS Omni-Agent Bootstrap Script
# Synchronizes manifests and initializes sub-project environments.

set -euo pipefail

echo "🚀 Initializing MiOS Omni-Agent Workspace..."

# 1. Generate Manifests
if [[ -f "tools/generate-ai-manifest.py" ]]; then
    echo "📄 Generating directory manifests..."
    python3 tools/generate-ai-manifest.py
else
    echo "⚠️ Warning: tools/generate-ai-manifest.py not found."
fi

# 2. Initialize deep-search-6418
if [[ -d "deep-search-6418" ]]; then
    echo "🧪 Initializing deep-search-6418 (Agent Starter Pack)..."
    (cd deep-search-6418 && make install)
else
    echo "⚠️ Warning: deep-search-6418 directory not found."
fi

# 3. Persistence: Refresh environment configs and dotfiles
echo "💾 Persisting environment state..."
if [[ -f "tools/refresh-env.py" ]]; then
    python3 tools/refresh-env.py
else
    echo "⚠️ Warning: tools/refresh-env.py not found."
fi

echo "✅ Workspace initialization complete."
