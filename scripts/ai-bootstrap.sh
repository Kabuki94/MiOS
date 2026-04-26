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

# 2. Initialize GCE-Research
if [[ -d "GCE-Research" ]]; then
    echo "🧪 Initializing GCE-Research (Agent Starter Pack)..."
    (cd GCE-Research && make install)
else
    echo "⚠️ Warning: GCE-Research directory not found."
fi

# 3. Persistence: Refresh environment configs and dotfiles
echo "💾 Persisting environment state..."
if [[ -f "tools/refresh-env.py" ]]; then
    python3 tools/refresh-env.py
else
    echo "⚠️ Warning: tools/refresh-env.py not found."
fi

echo "✅ Workspace initialization complete."
