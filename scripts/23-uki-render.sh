#!/usr/bin/env bash
set -eoux pipefail

echo "==> Preparing Unified Kernel Image (UKI) configuration..."

# Install ukify and required binary utilities
dnf install -y systemd-ukify binutils

# In a bootc Containerfile build, we use `bootc container render-kargs`
# to flatten all kargs.d/*.toml drop-ins into a single string for the UKI.
if command -v bootc >/dev/null; then
    echo "==> Rendering bootc kargs for UKI..."
    bootc container render-kargs > /etc/kernel/cmdline || true
else
    echo "==> bootc command not found, skipping karg render."
fi

# The actual UKI generation (`ukify build`) occurs in the final CI/CD pipeline
echo "==> UKI cmdline preparation complete."
