#!/bin/bash
# [NET] MiOS
# 37-ai-agnostic: Configure Unified AI API Redirects and agnostic environment
set -euo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

log "Configuring Unified AI API Agnostic patterns..."

# 1. Create system-wide AI configuration directory (USR-OVER-ETC)
AI_LIB_DIR="/usr/lib/mios/ai"
mkdir -p "$AI_LIB_DIR"

# 2. Deploy default redirect map
cat > "${AI_LIB_DIR}/default-redirects.json" <<'EOF'
{
  "version": "1.0.0",
  "defaults": {
    "primary": "local",
    "fallback": "gemini"
  },
  "endpoints": {
    "local": "http://localhost:8080/v1",
    "gemini": "https://us-central1-aiplatform.googleapis.com/v1",
    "claude": "https://api.anthropic.com/v1"
  }
}
EOF

# 3. Configure agnostic environment variables for all users
# We use /etc/environment.d/ for persistent environment variables on systemd systems.
# v0.1.3: Standardized Agnostic Mapping
ENV_DIR="/etc/environment.d"
mkdir -p "$ENV_DIR"

cat > "${ENV_DIR}/90-mios-ai-agnostic.conf" <<'EOF'
# MiOS Unified AI Agnostic Environment
# Redirects agnostic variables to the active provider.
# Default priority: Local (FOSS) -> Gemini -> Claude

# Agnostic Key (Redirects to provider-specific key at runtime)
MIOS_AI_KEY=${MIOS_AI_KEY:-}

# Agnostic Model (Maps to standard production models)
MIOS_AI_MODEL=${MIOS_AI_MODEL:-gemini-2.0-pro}

# Agnostic Endpoint (Target for OpenAI-compatible clients)
MIOS_AI_ENDPOINT=${MIOS_AI_ENDPOINT:-http://localhost:8080/v1}

# Legacy Compatibility
OPENAI_API_BASE=${MIOS_AI_ENDPOINT}
OPENAI_API_KEY=${MIOS_AI_KEY}
EOF

# 4. Initialize runtime state directory
# Note: /run is volatile, this is just for build-time verification
mkdir -p /run/mios/ai
ln -sf "${AI_LIB_DIR}/default-redirects.json" /run/mios/ai/active-redirects

log "Unified AI Agnostic patterns staged."
