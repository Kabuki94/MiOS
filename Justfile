# CloudWS v1.3.0 — Linux Build Targets
# Requires: podman, just
# Usage: just build | just iso | just all

IMAGE_NAME := "ghcr.io/kabuki94/cloudws-bootc"
VERSION := `cat VERSION 2>/dev/null || echo "1.3.0"`
LOCAL := "localhost/cloudws:latest"
BIB := "quay.io/centos-bootc/bootc-image-builder:latest"

# Build OCI image
build:
    podman build --no-cache -t {{LOCAL}} .
    @echo "✓ Built: {{LOCAL}}"

# Rechunk for optimal Day-2 updates (5-10x smaller deltas)
rechunk: build
    podman run --rm \
        --security-opt label=type:unconfined_t \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{LOCAL}} \
        /usr/libexec/bootc-base-imagectl rechunk containers-storage:{{LOCAL}} containers-storage:{{IMAGE_NAME}}:{{VERSION}}
    podman tag {{IMAGE_NAME}}:{{VERSION}} {{IMAGE_NAME}}:latest
    @echo "✓ Rechunked: {{IMAGE_NAME}}:{{VERSION}}"

# Generate RAW bootable disk image (80 GiB root)
raw: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/bib.toml:/config.toml:ro \
        {{BIB}} build --type raw --rootfs ext4 {{LOCAL}}
    @echo "✓ RAW image in output/"

# Generate Anaconda installer ISO
# FIX v1.3.0: ONLY mount iso.toml (includes minsize). Do NOT also mount bib config.
# BIB crashes with: "found config.json and also config.toml"
iso: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
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
        -v ./config/bib.toml:/config.toml:ro \
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

# Automated boot test via QEMU (requires nested virtualization)
# v1.3.0: Added for architectural validation.
boot-test: build
    mkdir -p output/qcow2
    @echo "Building QCOW2 image for boot validation..."
    sudo podman run --rm --privileged \
      --security-opt label=type:unconfined_t \
      -v ./output/qcow2:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      {{BIB}} build --type qcow2 --rootfs ext4 {{LOCAL}}
    @echo "Starting QEMU boot validation (waiting for graphical.target)..."
    chmod +x tests/qemu-boot-check.sh
    ./tests/qemu-boot-check.sh ./output/qcow2/qcow2/disk.qcow2

# Validate with bootc lint
lint:
    podman run --rm {{LOCAL}} bootc container lint

# Generate Unified Kernel Image (UKI)
# Note: requires a running podman and local image.
ukify:
    mkdir -p output
    podman run --rm -it --privileged \
        -v ./output:/output \
        {{LOCAL}} \
        bootc container ukify --rootfs / -- --output /output/cloudws-uki.efi
    @echo "✓ UKI generated in output/cloudws-uki.efi"

# Run cloudws-test inside the image
test:
    podman run --rm --privileged {{LOCAL}} /usr/bin/cloudws-test --quick

# Fix already-deployed systems that have localhost as update origin
switch:
    @echo "Run this ON the deployed CloudWS system to fix update origin:"
    @echo "  sudo bootc switch {{IMAGE_NAME}}:latest"

# Compile monolithic system extension (Consolidates NVIDIA/CUDA/Runtimes)
# Fixes 'overlayfs: maximum fs stacking depth exceeded'
sysext:
    chmod +x tools/cloudws-sysext-pack.sh
    sudo ./tools/cloudws-sysext-pack.sh /usr/lib/extensions/source/*
    @echo "✓ Monolithic sysext generated in /usr/lib/extensions/cloudws-accelerator.raw"

# Enable PXE Hub (netboot.xyz)
pxe-on:
    @echo "FEATURES=\"pxe-hub\"" | sudo tee -a /etc/cloudws/role.conf
    sudo systemctl restart cloudws-role.service
    @echo "✓ PXE Hub enabled"

# Disable PXE Hub
pxe-off:
    sudo sed -i '/pxe-hub/d' /etc/cloudws/role.conf
    sudo systemctl stop cloudws-pxe-hub.service
    @echo "✓ PXE Hub disabled"

# Migrate existing Fedora/CentOS root to CloudWS-bootc (Cloud Migration)
# WARNING: This overwrites your existing root filesystem!
install-to-root:
    @echo "Migrating system to CloudWS-bootc..."
    sudo bootc install to-existing-root --karg="console=ttyS0,115200n8" --imgref {{IMAGE_NAME}}:latest
    @echo "✓ Migration staged. Reboot to complete."

# Clean build artifacts
clean:
    rm -rf output/
    podman rmi {{LOCAL}} 2>/dev/null || true
    podman rmi {{IMAGE_NAME}}:latest 2>/dev/null || true
    @echo "✓ Cleaned"
