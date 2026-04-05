# CloudWS v1.0 — Justfile
# Usage: just build, just iso, just push, just clean
#
# FIXES in v1.1:
#   - BIB targets use GHCR ref (not localhost) so bootc upgrade works
#   - --local flag removed (it's the default in current BIB)
#   - Added 'switch' target to fix already-deployed localhost images
set shell := ["bash", "-euo", "pipefail", "-c"]

IMAGE_NAME := env_var_or_default("IMAGE_NAME", "ghcr.io/kabuki94/cloudws-bootc")
VERSION := `cat VERSION 2>/dev/null || echo "1.0.0"`
LOCAL := "localhost/cloudws:latest"
BIB := "quay.io/centos-bootc/bootc-image-builder:latest"

# Build the CloudWS OCI container image
build:
    podman build --no-cache -t {{LOCAL}} .
    # Tag with GHCR ref so BIB records the correct update origin
    podman tag {{LOCAL}} {{IMAGE_NAME}}:{{VERSION}}
    podman tag {{LOCAL}} {{IMAGE_NAME}}:latest
    @echo "✓ Built: {{LOCAL}} (also tagged as {{IMAGE_NAME}}:latest)"

# Rechunk for optimized Day-2 updates
rechunk: build
    sudo podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/centos-bootc:stream10 \
        /usr/libexec/bootc-base-imagectl rechunk {{LOCAL}} {{IMAGE_NAME}}:{{VERSION}}
    @echo "✓ Rechunked: {{IMAGE_NAME}}:{{VERSION}}"

# Generate RAW disk image (80 GiB root via config.json)
# Uses GHCR-tagged image so the installed system checks GHCR for updates.
# Image resolves from local storage via the volume mount — no network pull.
raw: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        {{BIB}} build --type raw --rootfs ext4 {{IMAGE_NAME}}:latest
    @echo "✓ RAW image in output/"

# Generate Anaconda installer ISO
iso: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        {{BIB}} build --type anaconda-iso --rootfs ext4 {{IMAGE_NAME}}:latest
    @echo "✓ ISO in output/"

# Generate VHD for Hyper-V
vhd: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        {{BIB}} build --type vhd --rootfs ext4 {{IMAGE_NAME}}:latest
    @echo "✓ VHD in output/"

# Export WSL2 tarball
wsl: build
    mkdir -p output
    podman create --name cloudws-wsl-tmp {{LOCAL}} 2>/dev/null || true
    podman export cloudws-wsl-tmp -o output/cloudws-wsl.tar
    podman rm cloudws-wsl-tmp
    @echo "✓ WSL tarball: output/cloudws-wsl.tar"

# Push to container registry
push:
    podman push {{IMAGE_NAME}}:{{VERSION}}
    podman push {{IMAGE_NAME}}:latest
    @echo "✓ Pushed: {{IMAGE_NAME}}:{{VERSION}} + latest"

# Build all targets
all: build raw iso vhd wsl push

# Validate with bootc lint
lint:
    podman run --rm {{LOCAL}} bootc container lint

# Fix already-deployed systems that have localhost as update origin
switch:
    @echo "Run this ON the deployed CloudWS system to fix update origin:"
    @echo "  sudo bootc switch {{IMAGE_NAME}}:latest"

# Clean build artifacts
clean:
    rm -rf output/
    podman rmi {{LOCAL}} 2>/dev/null || true
    podman rmi {{IMAGE_NAME}}:latest 2>/dev/null || true
    @echo "✓ Cleaned"
