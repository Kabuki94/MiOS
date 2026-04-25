#!/bin/bash
# CloudWS v1.3.0 — 36-tools: CLI tools and consolidated cloudws command
# Installs all cloudws-* tools to /usr/bin/ and the master 'cloudws' CLI.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[36-tools] Configuring CloudWS CLI tools..."

# CLI tools are now delivered via system_files overlay at /usr/bin/
# We just need to ensure permissions are correct here for files that 
# might have lost the executable bit during git/Windows transfer.

TOOLS=(
    cloudws 
    cloudws-update 
    cloudws-rebuild 
    cloudws-build 
    cloudws-backup 
    cloudws-deploy 
    cloudws-status 
    cloudws-vfio-toggle 
    cloudws-vfio-check 
    iommu-groups
)

for tool in "${TOOLS[@]}"; do
    if [ -f "/usr/bin/$tool" ]; then
        chmod +x "/usr/bin/$tool"
    else
        echo "[36-tools] WARN: /usr/bin/$tool not found (should be in system_files overlay)"
    fi
done

# ═══ Install external scripts from build context ═══
# These are scripts that live in scripts/ and are installed to /usr/bin/
echo "[36-tools] Installing cloudws-toggle-headless and cloudws-test..."
for ext_tool in cloudws-toggle-headless cloudws-test; do
    if [ -f "${SCRIPT_DIR}/${ext_tool}" ]; then
        install -Dm0755 "${SCRIPT_DIR}/${ext_tool}" "/usr/bin/${ext_tool}"
    else
        echo "[36-tools] WARN: ${ext_tool} not found at ${SCRIPT_DIR}/${ext_tool}"
    fi
done

echo "[36-tools] CLI tools configuration complete. Run 'cloudws --help' for commands."
