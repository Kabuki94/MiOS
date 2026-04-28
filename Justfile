# MiOS v0.1.3 — Linux Build Targets
# Requires: podman, just
# Usage: just build | just iso | just all

# Load user environment from XDG-compliant configuration
# This sources $HOME/.config/mios/*.toml files and exports MIOS_* variables
_load_env := `bash -c 'source ./tools/load-user-env.sh 2>/dev/null || true'`

MIOS_REGISTRY_DEFAULT := "ghcr.io/kabuki94/mios" # @track:REGISTRY_DEFAULT
IMAGE_NAME := env_var_or_default("MIOS_IMAGE_NAME", MIOS_REGISTRY_DEFAULT)
MIOS_VAR_VERSION := "0.1.3" # @track:VAR_VERSION
VERSION := `cat VERSION 2>/dev/null || echo {{MIOS_VAR_VERSION}}`
LOCAL := env_var_or_default("MIOS_IMAGE_NAME", "localhost/mios:latest")
MIOS_IMG_BIB := "quay.io/centos-bootc/bootc-image-builder:latest" # @track:IMG_BIB
BIB := env_var_or_default("MIOS_BIB_IMAGE", MIOS_IMG_BIB)

# Build OCI image locally
build: artifact
    podman build --no-cache \
        --build-arg BASE_IMAGE={{env_var_or_default("MIOS_BASE_IMAGE", "ghcr.io/ublue-os/ucore-hci:stable-nvidia")}} \
        --build-arg MIOS_FLATPAKS={{env_var_or_default("MIOS_FLATPAKS", "")}} \
        -t {{LOCAL}} .
    @echo "✓ Built: {{LOCAL}}"

# Build OCI image with unified logging
build-logged: artifact
    @mkdir -p logs
    @LOG_FILE="logs/build-$(date -u +%Y%m%dT%H%M%SZ).log"
    @echo "---" | tee -a "${LOG_FILE}"
    @echo "▶️ CHECKPOINT: Starting MiOS build..." | tee -a "${LOG_FILE}"
    @echo "Unified log will be available at: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    @echo "---" | tee -a "${LOG_FILE}"
    @set -o pipefail; podman build --no-cache \
        --build-arg BASE_IMAGE={{env_var_or_default("MIOS_BASE_IMAGE", "ghcr.io/ublue-os/ucore-hci:stable-nvidia")}} \
        --build-arg MIOS_FLATPAKS={{env_var_or_default("MIOS_FLATPAKS", "")}} \
        -t {{LOCAL}} . 2>&1 | tee -a "${LOG_FILE}"
    @echo "---" | tee -a "${LOG_FILE}"
    @echo "✅ CHECKPOINT: MiOS build complete." | tee -a "${LOG_FILE}"
    @echo "Unified log available at: ${LOG_FILE}" | tee -a "${LOG_FILE}"
    @echo "---"

# Build OCI image with verbose output (no redirection)
build-verbose: artifact
    podman build --no-cache \
        --build-arg BASE_IMAGE={{env_var_or_default("MIOS_BASE_IMAGE", "ghcr.io/ublue-os/ucore-hci:stable-nvidia")}} \
        --build-arg MIOS_FLATPAKS={{env_var_or_default("MIOS_FLATPAKS", "")}} \
        -t {{LOCAL}} .

# Embed the most recent build log into the image
embed-log:
    @echo "▶️ Finding most recent build log..."
    @LOG_FILE=$$(ls -t logs/build-*.log 2>/dev/null | head -n 1)
    @if [ -z "$${LOG_FILE}" ]; then \
        echo "❌ No build logs found in logs/. Run 'just build-logged' first."; \
        exit 1; \
    fi
    @echo "  Found: $${LOG_FILE}"
    @echo "▶️ Creating temporary Containerfile to embed log..."
    @echo "FROM {{LOCAL}}" > /tmp/Containerfile.embed
    @echo "COPY --chown=root:root $${LOG_FILE} /usr/share/mios/build-logs/latest-build.log" >> /tmp/Containerfile.embed
    @echo "▶️ Building image with embedded log..."
    @set -o pipefail; podman build --no-cache -f /tmp/Containerfile.embed -t localhost/mios:latest-with-log .
    @rm /tmp/Containerfile.embed
    @echo "---"
    @echo "✅ Success! New image created: localhost/mios:latest-with-log"
    @echo "   Embedded log is at: /usr/share/mios/build-logs/latest-build.log"
    @echo "---"

# Refresh all AI manifests, UKB, and Wiki documentation
artifact:
    ./automation/ai-bootstrap.sh
    @echo "✓ Artifacts, UKB, and Wiki refreshed."

# Build OCI image on Cloud (using remote context)
cloud-build:
    @echo "Configure cloud-build with your cloud provider CLI"
    @echo "Example: podman build --remote -t {{IMAGE_NAME}}:{{VERSION}} ."
    @echo "✓ Cloud Build target (customize for your cloud provider)"

# Rechunk for optimal Day-2 updates (5-10x smaller deltas)
rechunk: build
    podman run --rm \
        --security-opt label=type:unconfined_t \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        {{LOCAL}} \
        /usr/libexec/bootc-base-imagectl rechunk --max-layers 67 containers-storage:{{LOCAL}} containers-storage:{{IMAGE_NAME}}:{{VERSION}}
    podman tag {{IMAGE_NAME}}:{{VERSION}} {{IMAGE_NAME}}:latest
    @echo "✓ Rechunked: {{IMAGE_NAME}}:{{VERSION}}"

# Generate RAW bootable disk image (80 GiB root)
raw: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/artifacts/bib.toml:/config.toml:ro \
        {{BIB}} build --type raw --rootfs ext4 {{LOCAL}}
    @echo "✓ RAW image in output/"

# Generate Anaconda installer ISO
# FIX v0.1.3: ONLY mount iso.toml (includes minsize). Do NOT also mount bib config.
# BIB crashes with: "found config.json and also config.toml"
iso: build
    mkdir -p output
    sudo podman run --rm -it --privileged \
        --security-opt label=type:unconfined_t \
        -v ./output:/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v ./config/artifacts/iso.toml:/config.toml:ro \
        {{BIB}} build --type iso --rootfs ext4 {{LOCAL}}
    @echo "✓ ISO image in output/"

# Log artifacts to MiOS-bootstrap repository (Linux FS native)
log-bootstrap:
    @echo "▶️ Logging artifacts to MiOS-bootstrap repository (Linux FS native)..."
    ./tools/prepare-bootstrap-native.sh
    @echo "✓ Artifacts logged to bootstrap repository"

# Complete build with bootstrap logging (recommended for releases)
build-and-log: build-logged
    @echo "▶️ Running bootstrap artifact logging (Linux FS native)..."
    ./tools/prepare-bootstrap-native.sh
    @echo "✅ Build complete with artifacts logged to bootstrap"

# Full pipeline: build → rechunk → log to bootstrap (Linux FS native)
all-bootstrap: build rechunk log-bootstrap
    @echo "✅ Full pipeline complete (build → rechunk → bootstrap Linux FS native)"

# Generate SBOM for the local image
sbom:
    @echo "▶️ Generating SBOM for {{LOCAL}}..."
    @mkdir -p artifacts/sbom
    podman run --rm \
        -v ./artifacts/sbom:/out \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        anchore/syft:latest scan {{LOCAL}} -o cyclonedx-json > artifacts/sbom/mios-sbom.json
    @echo "✅ SBOM generated: artifacts/sbom/mios-sbom.json"

# ============================================================================
# User-Space Management
# ============================================================================

# Initialize user-space configuration (XDG Base Directory structure)
init-user-space:
    @echo "🏗️  Initializing MiOS user-space..."
    ./tools/init-user-space.sh
    @echo "✅ User-space initialization complete"

# Re-initialize user-space (overwrite existing configs)
reinit-user-space:
    @echo "🔄 Re-initializing MiOS user-space (overwriting existing configs)..."
    ./tools/init-user-space.sh --force
    @echo "✅ User-space re-initialization complete"

# Show user-space configuration paths
show-user-space:
    @echo "MiOS User-Space Directories:"
    @echo "  Config:  ${XDG_CONFIG_HOME:-$HOME/.config}/mios/"
    @echo "  Data:    ${XDG_DATA_HOME:-$HOME/.local/share}/mios/"
    @echo "  Cache:   ${XDG_CACHE_HOME:-$HOME/.cache}/mios/"
    @echo "  State:   ${XDG_STATE_HOME:-$HOME/.local/state}/mios/"
    @echo "  Runtime: ${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mios/"
    @echo ""
    @echo "Configuration files:"
    @if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml" ]; then \
        echo "  ✅ env.toml"; \
    else \
        echo "  ❌ env.toml (not found - run: just init-user-space)"; \
    fi
    @if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/images.toml" ]; then \
        echo "  ✅ images.toml"; \
    else \
        echo "  ❌ images.toml (not found - run: just init-user-space)"; \
    fi
    @if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/build.toml" ]; then \
        echo "  ✅ build.toml"; \
    else \
        echo "  ❌ build.toml (not found - run: just init-user-space)"; \
    fi

# Show loaded environment variables
show-env:
    @echo "MiOS Environment Variables:"
    @source ./tools/load-user-env.sh && env | grep '^MIOS_' | sort | sed 's/^/  /'

# Edit user environment configuration
edit-env:
    @if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml" ]; then \
        echo "❌ User config not found. Run: just init-user-space"; \
        exit 1; \
    fi
    @${EDITOR:-vim} "${XDG_CONFIG_HOME:-$HOME/.config}/mios/env.toml"

# Edit user image configuration
edit-images:
    @if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/images.toml" ]; then \
        echo "❌ User config not found. Run: just init-user-space"; \
        exit 1; \
    fi
    @${EDITOR:-vim} "${XDG_CONFIG_HOME:-$HOME/.config}/mios/images.toml"

# Edit user build configuration
edit-build:
    @if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/build.toml" ]; then \
        echo "❌ User config not found. Run: just init-user-space"; \
        exit 1; \
    fi
    @${EDITOR:-vim} "${XDG_CONFIG_HOME:-$HOME/.config}/mios/build.toml"

# Edit Flatpak applications list
edit-flatpaks:
    @if [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/mios/flatpaks.list" ]; then \
        echo "❌ User config not found. Run: just init-user-space"; \
        exit 1; \
    fi
    @${EDITOR:-vim} "${XDG_CONFIG_HOME:-$HOME/.config}/mios/flatpaks.list"
