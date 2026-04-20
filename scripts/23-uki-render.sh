#!/usr/bin/env bash
set -euo pipefail

echo "==> Preparing Unified Kernel Image (UKI) configuration..."

# systemd-ukify and binutils are required for this step.
# Ensure they are declared in docs/PACKAGES.md per the single-source-of-truth rules.

# In a bootc Containerfile build, we use `bootc container render-kargs`
# to flatten all kargs.d/*.toml drop-ins into a single string for the UKI.
if command -v bootc >/dev/null && bootc container --help | grep -q 'render-kargs'; then
    echo "==> Rendering bootc kargs for UKI..."
    bootc container render-kargs > /etc/kernel/cmdline || true
else
    echo "==> bootc render-kargs not available yet in this version, skipping."
fi

# The actual UKI generation (`ukify build`) occurs in the final CI/CD pipeline
echo "==> UKI cmdline preparation complete."
