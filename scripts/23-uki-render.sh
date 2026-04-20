#!/usr/bin/env bash
set -euo pipefail

echo "==> Preparing Unified Kernel Image (UKI) configuration..."

# systemd-ukify and binutils are required for this step.
# Ensure they are declared in docs/PACKAGES.md per the single-source-of-truth rules.

# In a bootc Containerfile build, we use `bootc container render-kargs`
# to flatten all kargs.d/*.toml drop-ins into a single string for the UKI.
if command -v bootc >/dev/null && bootc container --help | grep -q 'render-kargs'; then
    echo "==> Rendering bootc kargs for UKI natively..."
    bootc container render-kargs > /etc/kernel/cmdline
else
    echo "==> bootc render-kargs not available, rendering flat TOML via Python fallback..."
    python3 -c '
import tomllib, sys, glob
kargs = []
for f in sorted(glob.glob("/usr/lib/bootc/kargs.d/*.toml")):
    with open(f, "rb") as fp:
        d = tomllib.load(fp)
        if "kargs" in d:
            kargs.extend(d["kargs"])
print(" ".join(kargs))
' > /etc/kernel/cmdline
fi

CMDLINE=$(cat /etc/kernel/cmdline | xargs)
if [ -z "$CMDLINE" ]; then
    echo "FATAL: /etc/kernel/cmdline is empty! UKI generation will fail."
    exit 1
fi

echo "Rendered UKI cmdline: $CMDLINE"
# The actual UKI generation (`ukify build`) occurs in the final CI/CD pipeline
echo "==> UKI cmdline preparation complete."
