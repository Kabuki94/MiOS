#!/usr/bin/env bash
set -euo pipefail
# CloudWS v2.1.4 — Secure Boot MOK Enrollment Helper
#
# Enrolls a Machine Owner Key for signing out-of-tree kernel modules.
# Supports sbctl (preferred) and mokutil (fallback).
#
# Usage:
#   enroll-mok.sh                   # Use default CloudWS key
#   enroll-mok.sh /path/to/key.der  # Use custom key

KEY="${1:-/etc/pki/cloudws/mok.der}"

echo "═══ CloudWS MOK Enrollment ═══"

if [[ ! -f "$KEY" ]]; then
    echo "Key not found: $KEY"
    echo ""
    echo "To generate a new MOK keypair:"
    echo "  sudo mkdir -p /etc/pki/cloudws"
    echo "  sudo openssl req -new -x509 -newkey rsa:2048 -keyout /etc/pki/cloudws/mok.priv \\"
    echo "    -outform DER -out /etc/pki/cloudws/mok.der -nodes -days 36500 \\"
    echo "    -subj '/CN=CloudWS Module Signing/'"
    exit 2
fi

if command -v sbctl >/dev/null 2>&1; then
    echo "Using sbctl (preferred)..."
    echo ""
    echo "Steps:"
    echo "  1. sudo sbctl create-keys"
    echo "  2. sudo sbctl enroll-keys -m"
    echo "  3. sudo sbctl sign -s /boot/vmlinuz-\$(uname -r)"
    echo "  4. sudo sbctl verify"
    echo ""
    echo "sbctl manages its own key database. The MOK at $KEY"
    echo "is for mokutil-based workflows (fallback)."
elif command -v mokutil >/dev/null 2>&1; then
    echo "Using mokutil..."
    echo "You will be prompted to set a one-time enrollment password."
    echo "On next reboot, the MOK Manager will ask for this password."
    echo ""
    sudo mokutil --import "$KEY"
    echo ""
    echo "✓ Key queued for enrollment. Reboot and complete in MOK Manager."
else
    echo "Neither sbctl nor mokutil found."
    echo "Install one of:"
    echo "  sudo dnf install sbctl        # Preferred"
    echo "  sudo dnf install mokutil       # Fallback"
    exit 3
fi