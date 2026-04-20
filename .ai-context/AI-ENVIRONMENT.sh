#!/bin/bash
# 🌐 CloudWS-bootc AI-AGENT ENVIRONMENT (v2.3.5)
# This file is NATIVELY PARSABLE by all shell-aware AI Agents and APIs.
# It defines the engineering baseline and strict build policies.

export AI_ARCH_BASELINE="v2.3.5"
export AI_DNF_POLICY='--setopt=install_weak_deps=False'
export AI_WSL_GATING="ConditionVirtualization=!wsl"
export AI_OVERLAY_PATH="system_files/"
export AI_PKG_SOURCE="docs/PACKAGES.md"
export AI_COSIGN_PIN="v2.6.3"

# Metadata for context-aware harnesses
export AI_WORKSPACE_TYPE="bootable-container"
export AI_BASE_IMAGE="ghcr.io/ublue-os/ucore-hci:stable-nvidia"
export AI_JOURNALING_LAW="MANDATORY"
export AI_DNF_SETOPT='("--setopt=install_weak_deps=False")'

echo "✓ CloudWS AI-Environment $AI_ARCH_BASELINE loaded."
