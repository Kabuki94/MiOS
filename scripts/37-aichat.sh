#!/bin/bash
# 🌐 CloudWS-bootc — Universal AI Integration
# 37-aichat: Install AIChat and AIChat-NG Rust CLI tools
set -euo pipefail

echo "[37-aichat] Installing AIChat and AIChat-NG..."

# Fetch latest release tags
AICHAT_TAG=$(curl -s https://api.github.com/repos/sigoden/aichat/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
AICHAT_NG_TAG=$(curl -s https://api.github.com/repos/blob42/aichat-ng/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

echo "[37-aichat] Detected AIChat version: ${AICHAT_TAG}"
echo "[37-aichat] Detected AIChat-NG version: ${AICHAT_NG_TAG}"

# Download and install AIChat
curl -L -o /tmp/aichat.tar.gz "https://github.com/sigoden/aichat/releases/download/${AICHAT_TAG}/aichat-${AICHAT_TAG}-x86_64-unknown-linux-musl.tar.gz"
tar -xzf /tmp/aichat.tar.gz -C /usr/bin/ aichat
chmod +x /usr/bin/aichat

# Download and install AIChat-NG
curl -L -o /tmp/aichat-ng.tar.gz "https://github.com/blob42/aichat-ng/releases/download/${AICHAT_NG_TAG}/aichat-ng-${AICHAT_NG_TAG}-x86_64-unknown-linux-musl.tar.gz"
tar -xzf /tmp/aichat-ng.tar.gz -C /usr/bin/ aichat-ng
chmod +x /usr/bin/aichat-ng

# Cleanup
rm -f /tmp/aichat.tar.gz /tmp/aichat-ng.tar.gz

echo "[37-aichat] AIChat and AIChat-NG installed successfully."
