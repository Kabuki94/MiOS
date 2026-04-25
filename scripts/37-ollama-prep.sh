#!/bin/bash
# 🌐 CloudWS-bootc — Universal AI Integration
# 37-ollama-prep: Embed default LLM models during build
set -euo pipefail

# This script is intended for local builds to "bake in" the default coding model.
# It installs a temporary ollama binary, pulls the model, and cleans up.

# Only run if not already present (idempotency)
if [ -d "/var/lib/ollama/models" ] && [ "$(ls -A /var/lib/ollama/models)" ]; then
    echo "[37-ollama-prep] Default models already present, skipping."
    exit 0
fi

echo "[37-ollama-prep] Downloading default model: deepseek-coder-v2:lite..."

# Install temporary ollama binary
curl -L https://ollama.com/download/ollama-linux-amd64 -o /tmp/ollama
chmod +x /tmp/ollama

# Start ollama serve in background
# We need to set OLLAMA_MODELS to the target path
export OLLAMA_MODELS="/var/lib/ollama"
mkdir -p "$OLLAMA_MODELS"

/tmp/ollama serve &
OLLAMA_PID=$!

# Wait for server to be ready
echo "Waiting for Ollama server to start..."
MAX_RETRIES=15
COUNT=0
while ! curl -s http://localhost:11434/api/tags > /dev/null; do
    sleep 2
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Ollama server failed to start."
        kill $OLLAMA_PID
        exit 1
    fi
done

# Pull the model
/tmp/ollama pull deepseek-coder-v2:lite

# Shutdown server
kill $OLLAMA_PID
wait $OLLAMA_PID || true

# Cleanup binary
rm -f /tmp/ollama

echo "[37-ollama-prep] Model embedded successfully."
