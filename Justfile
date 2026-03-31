# CloudWS v1.0 — Justfile
# Usage: just build, just iso, just push, just clean
set shell := ["bash", "-euo", "pipefail", "-c"]

IMAGE_NAME := env_var_or_default("IMAGE_NAME", "ghcr.io/kabuki94/cloudws-bootc")
VERSION := `cat VERSION 2>/dev/null || echo "1.0.0"`
LOCAL := "localhost/cloudws:latest"
BIB := "quay.io/centos-bootc/bootc-image-builder:latest"

# Build the CloudWS OCI container image
build:
    podman build --no-cache -t {{LOCAL}} .
    @echo "✓ Built: {{LOCAL}}"

# Rechunk for optimized Day-2 updates
rechunk: build
    sudo podman run --rm --privileged \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/centos-bootc:stream10 \
        /usr/libexec/bootc-base-imagectl rechunk {{LOCAL}} {{IMAGE_NAME}}:{{VERSION}}
    @echo "✓ Rechunked: {{IMAGE_NAME}}:{{VERSION}}"

# Generate RAW disk image
raw:
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{BIB}} --type raw --rootfs ext4 --local {{LOCAL}}
    @echo "✓ RAW image in output/"

# Generate Anaconda installer ISO
iso:
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{BIB}} --type anaconda-iso --rootfs ext4 --local {{LOCAL}}
    @echo "✓ ISO in output/"

# Generate VHD for Hyper-V (convert to VHDX manually with qemu-img)
vhd:
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{BIB}} --type vhd --rootfs ext4 --local {{LOCAL}}
    @echo "✓ VHD in output/"

# Export WSL2 tarball
wsl:
    podman create --name cloudws-wsl-tmp {{LOCAL}} 2>/dev/null || true
    podman export cloudws-wsl-tmp -o output/cloudws-wsl.tar
    podman rm cloudws-wsl-tmp
    @echo "✓ WSL tarball: output/cloudws-wsl.tar"

# Push to container registry
push:
    podman tag {{LOCAL}} {{IMAGE_NAME}}:{{VERSION}}
    podman tag {{LOCAL}} {{IMAGE_NAME}}:latest
    podman push {{IMAGE_NAME}}:{{VERSION}}
    podman push {{IMAGE_NAME}}:latest
    @echo "✓ Pushed: {{IMAGE_NAME}}:{{VERSION}}"

# Build all targets
all: build raw iso vhd wsl push

# Validate with bootc lint
lint:
    podman run --rm {{LOCAL}} bootc container lint

# Clean build artifacts
clean:
    rm -rf output/
    podman rmi {{LOCAL}} 2>/dev/null || true
    @echo "✓ Cleaned"
