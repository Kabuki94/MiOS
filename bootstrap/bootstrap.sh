#!/bin/bash
# MiOS Public Bootstrap for Linux/WSL
# Repository: Kabuki94/mios-bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/Kabuki94/mios-bootstrap/main/bootstrap.sh | bash

set -euo pipefail

PRIVATE_REPO="https://raw.githubusercontent.com/Kabuki94/mios/main"

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  🌐 MiOS Private Bootstrap (Linux/WSL)                       ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ -z "${GHCR_TOKEN:-}" ]]; then
    read -rsp "  Enter GitHub Personal Access Token (requires 'repo' scope): " GHCR_TOKEN
    echo ""
    export GHCR_TOKEN
fi

if [[ -z "$GHCR_TOKEN" ]]; then
    echo "  [!] Token required to access the private MiOS repository."
    exit 1
fi

echo "  [+] Fetching private installer..."
# Use GitHub PAT in the Authorization header
if curl -fsSL -H "Authorization: token $GHCR_TOKEN" "$PRIVATE_REPO/install.sh" -o /tmp/mios-install.sh; then
    echo "  [OK] Handoff to private installer."
    echo ""
    bash /tmp/mios-install.sh
else
    echo "  [!] Failed to fetch private installer. Check your token and repository permissions."
    exit 1
fi
