#!/usr/bin/env bash
set -euo pipefail

# Escalate if sudo is available
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

echo "MiOS Devcontainer: performing post-create setup..."

# 1) Install kubectl (stable) if missing
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl..."
  KUBECTL_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  ${SUDO} curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
  ${SUDO} chmod +x /usr/local/bin/kubectl
fi

# 2) Install Helm (if missing)
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | ${SUDO} bash
fi

# 3) Group Permissions
if [ -e /var/run/docker.sock ] && getent group docker >/dev/null 2>&1; then
    ${SUDO} usermod -aG docker $(id -un) || true
fi

# 4) Agent Sync Context
echo ">>> Initializing Agent Workspace Context..."
if [ ! -f "$HOME/.ai/.ide_setup_complete" ]; then
    echo "================================================================="
    echo "MiOS Dev Container: AI-Native Initialization"
    echo "================================================================="
    echo "To initialize the session context, run:"
    echo "  ./automation/ai-bootstrap.sh"
    echo "================================================================="
    mkdir -p "$HOME/.ai"
    touch "$HOME/.ai/.ide_setup_complete"
fi

echo "MiOS devcontainer setup complete."
