#!/usr/bin/bash
# 53-bake-lookingglass-client.sh - git clone Looking Glass B7, cmake/make,
# install looking-glass-client binary to /usr/bin/. BAKED IN. No runtime
# compile. No "feature service". The binary is present in every image.
set -euo pipefail

log() { printf '[53-lg-client] %s\n' "$*"; }

LG_BRANCH="${LG_BRANCH:-B7}"
BUILD_DIR="/tmp/LookingGlass-build"

# --- Clone -----------------------------------------------------------------
log "cloning Looking Glass $LG_BRANCH"
rm -rf "$BUILD_DIR"
git clone --depth 1 --branch "$LG_BRANCH" --recurse-submodules \
    https://github.com/gnif/LookingGlass.git "$BUILD_DIR" || {
    log "ERROR: git clone failed"
    exit 1
}

# --- Configure + build client ---------------------------------------------
log "configuring client build"
mkdir -p "$BUILD_DIR/client/build"
cd "$BUILD_DIR/client/build"
cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_BACKTRACE=OFF .. || {
    log "ERROR: cmake configure failed"
    log "       missing -devel packages? Check 51-install-unified-packages.sh"
    exit 1
}

log "building looking-glass-client (jobs=$(nproc))"
make -j"$(nproc)" || {
    log "ERROR: make failed"
    exit 1
}

# --- Install binary + desktop file ----------------------------------------
log "installing binary to /usr/bin/looking-glass-client"
install -Dm0755 looking-glass-client /usr/bin/looking-glass-client

# Ship a .desktop entry
install -Dm0644 /dev/stdin /usr/share/applications/looking-glass.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=Looking Glass
Comment=Low-latency KVM display from a VM via shared memory
Icon=video-display
Exec=looking-glass-client
Terminal=false
Categories=System;Utility;
Keywords=KVM;VFIO;Passthrough;
DESK

# --- Cleanup build tree (keep toolchain in image per self-building principle) ---
log "cleaning up source tree"
cd /
rm -rf "$BUILD_DIR"

# --- Verify ----------------------------------------------------------------
if [[ -x /usr/bin/looking-glass-client ]]; then
    log "OK: looking-glass-client baked in at /usr/bin/looking-glass-client"
    /usr/bin/looking-glass-client --version 2>&1 | head -5 || true
else
    log "ERROR: binary missing after install"
    exit 1
fi

log "Looking Glass client BAKED IN"