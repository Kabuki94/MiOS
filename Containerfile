# CloudWS v1.0 — Containerfile
# Build: podman build --no-cache -t cloudws:latest .
# Lint:  podman run --rm cloudws:latest bootc container lint

# ── Stage 1: Build context (never enters final image) ────────────────────────
FROM scratch AS ctx
COPY scripts/ /scripts/
COPY PACKAGES.md /
COPY VERSION /
COPY system_files/ /system_files/

# ── Stage 2: CloudWS bootc image ─────────────────────────────────────────────
FROM quay.io/fedora/fedora-bootc:rawhide

# Copy scripts to writable location, fix line endings, then execute.
# The bind mount from ctx is READ-ONLY — sed -i and chmod fail on it.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    mkdir -p /tmp/build && \
    cp -a /ctx/scripts /tmp/build/scripts && \
    cp /ctx/PACKAGES.md /tmp/build/PACKAGES.md && \
    cp /ctx/VERSION /tmp/build/VERSION && \
    find /tmp/build -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    find /tmp/build -name "*.md" -exec sed -i 's/\r$//' {} + && \
    chmod +x /tmp/build/scripts/*.sh /tmp/build/scripts/lib/*.sh && \
    PACKAGES_MD=/tmp/build/PACKAGES.md bash /tmp/build/scripts/build.sh && \
    rm -rf /tmp/build

# System file overlay (configs, systemd units, modprobe.d, dconf, etc.)
# Also read-only mount — use cp -a to copy into the live filesystem.
RUN --mount=type=bind,from=ctx,source=/system_files,target=/tmp/sf \
    cp -a /tmp/sf/. / && \
    dconf update 2>/dev/null || true

LABEL containers.bootc 1
LABEL ostree.bootable 1
RUN bootc container lint
