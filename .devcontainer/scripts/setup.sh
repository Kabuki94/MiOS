#!/usr/bin/env bash\nset -euo pipefail\n\n# Run as root when needed — container's postCreateCommand runs as the 'vscode' user,\n# escalate if sudo is available.\nSUDO=""\nif [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then\n  SUDO="sudo"\nfi\n\necho "MiOS devcontainer: performing post-create setup..."\n\n# 1) Install kubectl (stable) if missing\nif ! command -v kubectl >/dev/null 2>&1; then\n  echo "Installing kubectl..."\n  KUBECTL_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)\n  ${SUDO} curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl\n  ${SUDO} chmod +x /usr/local/bin/kubectl\nfi\n\n# 2) Install Helm (if missing)\nif ! command -v helm >/dev/null 2>&1; then\n  echo "Installing helm..."\n  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | ${SUDO} bash\nfi\n\n# 3) Add 'vscode' to docker group if docker socket exists and group exists
if [ -e /var/run/docker.sock ]; then
  if getent group docker >/dev/null 2>&1; then
    echo "Adding user to docker group..."
    ${SUDO} usermod -aG docker $(id -un) || true
  fi
fi

echo ">>> Bootstrapping Node.js (Long Term Support)..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | ${SUDO} -E bash -
    ${SUDO} apt-get install -y nodejs
fi

echo ">>> Installing @google/gemini-cli..."
${SUDO} npm install -g @google/gemini-cli@latest

echo ">>> Preparing IDE Extension Inter-Process Communication context..."
cat << 'EOF_BASH' >> "$HOME/.bashrc"
if [ ! -f "$HOME/.gemini/.ide_setup_complete" ]; then
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

echo "MiOS devcontainer setup complete. You may need to reload the VS Code window."