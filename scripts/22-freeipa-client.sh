#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing FreeIPA & SSSD for zero-touch enrollment..."

# Install the FreeIPA client and SSSD tooling into the immutable root
dnf install -y freeipa-client sssd-tools

# Enable the zero-touch enrollment service so it arms on first boot
systemctl enable cloudws-freeipa-enroll.service
