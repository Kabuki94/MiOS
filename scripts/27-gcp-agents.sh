#!/usr/bin/bash
# CloudWS v1.3.0 — 27-gcp-agents: Google Cloud Platform guest environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/packages.sh"

echo "[27-gcp-agents] Installing GCP guest agents..."
install_packages "gcp"

# Enable services
echo "[27-gcp-agents] Enabling GCP services..."
systemctl enable google-guest-agent.service 2>/dev/null || true
systemctl enable google-osconfig-agent.service 2>/dev/null || true

echo "[27-gcp-agents] GCP guest environment configuration complete."
