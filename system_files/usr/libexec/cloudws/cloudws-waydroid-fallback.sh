#!/usr/bin/env bash
set -eou pipefail

# If the system uses an NVIDIA GPU, Waydroid's Android container will crash
# due to missing Mesa EGL support. We must force CPU software rendering (SwiftShader).
if lspci | grep -qi "VGA compatible controller: NVIDIA"; then
    echo "==> NVIDIA GPU detected. Forcing Waydroid to use SwiftShader EGL..."

    # Initialize or update the waydroid config
    touch /var/lib/waydroid/waydroid.cfg
    if ! grep -q "ro.hardware.egl=swiftshader" /var/lib/waydroid/waydroid.cfg; then
        echo "ro.hardware.egl=swiftshader" >> /var/lib/waydroid/waydroid.cfg
        echo "ro.hardware.vulkan=swiftshader" >> /var/lib/waydroid/waydroid.cfg
    fi
fi
exit 0
