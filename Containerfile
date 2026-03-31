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

# Single RUN layer with bind mounts — scripts never enter the image
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    find /ctx/scripts -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    chmod +x /ctx/scripts/*.sh /ctx/scripts/lib/*.sh && \
    bash /ctx/scripts/build.sh

# System file overlay (configs, systemd units, modprobe.d, dconf, etc.)
RUN --mount=type=bind,from=ctx,source=/system_files,target=/tmp/sf \
    cp -a /tmp/sf/. / && \
    dconf update 2>/dev/null || true

LABEL containers.bootc 1
LABEL ostree.bootable 1
RUN bootc container lint
