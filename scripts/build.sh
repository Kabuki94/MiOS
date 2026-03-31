#!/bin/bash
# CloudWS — Master build runner
# Executes all numbered scripts in order, then cleans up.
# Called from Containerfile RUN layer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PACKAGES_MD="${PACKAGES_MD:-${SCRIPT_DIR}/../PACKAGES.md}"

VERSION=$(cat "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "1.0.0")

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS v${VERSION} — Building OS Image                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  PACKAGES.MD : $PACKAGES_MD"
echo "  SCRIPT_DIR  : $SCRIPT_DIR"
echo ""

# Validate PACKAGES.md is accessible
if [[ ! -f "$PACKAGES_MD" ]]; then
    echo "FATAL: $PACKAGES_MD not found. Build context missing."
    exit 1
fi

# Execute all numbered scripts in order
for script in "$SCRIPT_DIR"/[0-9][0-9]-*.sh; do
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ==> Running: $(basename "$script")"
    echo "═══════════════════════════════════════════════════════════════"
    bash "$script"
done

# Final cleanup — must be in same layer as installs
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ==> Final cleanup"
echo "═══════════════════════════════════════════════════════════════"
dnf clean all
rm -rf /var/cache/dnf /var/cache/rpm /var/log/* /root/.cache /tmp/*

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  CloudWS build complete                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
