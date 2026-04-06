# CloudWS v1.2 — Justfile
# Linux-native build targets. Requires: podman, just
# Usage: just build | just iso | just all

IMAGE_NAME := "ghcr.io/kabuki94/cloudws-bootc"
VERSION := `cat VERSION 2>/dev/null || echo "1.2.0"`
LOCAL := "localhost/cloudws:latest"
BIB := "quay.io/centos-bootc/bootc-image-builder:latest"
RECHUNK := "quay.io/centos-bootc/centos-bootc:stream10"

# Build OCI image
build:
    podman build --squash-all --no-cache -t {{LOCAL}} .
    @echo "✓ Built: {{LOCAL}}"

# Rechunk for optimal Day-2 updates (5-10x smaller deltas)
rechunk: build
    podman run --rm \
        --security-opt label=type:unconfined_t \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{RECHUNK}} \
        bootc-base-imagectl rechunk containers-storage:{{LOCAL}} containers-storage:{{IMAGE_NAME}}:{{VERSION}}
    podman tag {{IMAGE_NAME}}:{{VERSION}} {{IMAGE_NAME}}:latest
    @echo "✓ Rechunked: {{IMAGE_NAME}}:{{VERSION}}"

# Generate RAW bootable disk image (80 GiB root)
raw: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        {{BIB}} build --type raw --rootfs ext4 {{LOCAL}}
    @echo "✓ RAW image in output/"

# Generate Anaconda installer ISO (uses iso.toml kickstart)
iso: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        -v ./iso.toml:/config.toml:ro \
        {{BIB}} build --type anaconda-iso --rootfs ext4 {{LOCAL}}
    @echo "✓ ISO in output/"

# Generate VHD for Hyper-V
vhd: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.json:/config.json:ro \
        {{BIB}} build --type vhd --rootfs ext4 {{LOCAL}}
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
all: build rechunk raw iso vhd wsl push

# Validate with bootc lint
lint:
    podman run --rm {{LOCAL}} bootc container lint

# Run cloudws-test inside the image
test:
    podman run --rm --privileged {{LOCAL}} /usr/bin/cloudws-test --quick

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
