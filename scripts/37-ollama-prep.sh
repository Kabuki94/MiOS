#!/bin/bash
# 🌐 MiOS — Universal AI Integration
# 37-ollama-prep: Embed default LLM models during build
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

# This script is intended for local builds to "bake in" the default coding model.
# It installs a temporary ollama binary, pulls the model, and cleans up.

# Only run if not already present (idempotency)
if [ -d "/var/lib/ollama/models" ] && [ "$(ls -A /var/lib/ollama/models)" ]; then
    log "Default models already present, skipping."
    exit 0
fi

log "Downloading default model: deepseek-coder-v2:lite..."

# Install temporary ollama binary from GitHub releases (direct binary)
# Using -L to follow redirects. 
OLLAMA_URL="https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64"
log "URL: $OLLAMA_URL"
scurl -L "$OLLAMA_URL" -o /tmp/ollama
chmod +x /tmp/ollama

# Validation: ensure we didn't download a 404 page or empty file
if ! file /tmp/ollama | grep -q "ELF"; then
    log "ERROR: /tmp/ollama is not a valid ELF binary. Download likely failed."
    log "File content (first 100 bytes):"
    head -c 100 /tmp/ollama
    echo ""
    exit 1
fi

# Start ollama serve in background
# We need to set OLLAMA_MODELS to the target path
export OLLAMA_MODELS="/var/lib/ollama"
mkdir -p "$OLLAMA_MODELS"

/tmp/ollama serve &
OLLAMA_PID=$!

# Wait for server to be ready
log "Waiting for Ollama server to start..."
MAX_RETRIES=15
COUNT=0
while ! scurl -s http://localhost:11434/api/tags > /dev/null; do
    sleep 2
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        log "ERROR: Ollama server failed to start."
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
