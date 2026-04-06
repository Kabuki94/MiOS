# CloudWS v1.2 — Containerfile
# Build: podman build --squash-all --no-cache -t cloudws:latest .
# Lint:  podman run --rm cloudws:latest bootc container lint

# ── Stage 1: Build context (never enters final image) ────────────────────────
FROM scratch AS ctx
COPY scripts/ /scripts/
COPY PACKAGES.md /
COPY VERSION /
COPY system_files/ /system_files/

# ── Stage 2: CloudWS bootc image ─────────────────────────────────────────────
FROM quay.io/fedora/fedora-bootc:rawhide

# CRITICAL: Bind mount from ctx is READ-ONLY.
# Must copy to writable /tmp/build before sed -i or chmod.
#
# SYSTEMD_OFFLINE=1 prevents %post/%triggerin scriptlets from trying to
# start/enable systemd services (which hangs forever inside container builds).
# container=podman tells systemd-aware scriptlets they're in a container.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    export SYSTEMD_OFFLINE=1 && \
    export container=podman && \
    mkdir -p /tmp/build && \
    cp -a /ctx/scripts /tmp/build/scripts && \
    cp /ctx/PACKAGES.md /tmp/build/PACKAGES.md && \
    cp /ctx/VERSION /tmp/build/VERSION && \
    find /tmp/build -name "*.sh" -exec sed -i 's/\r$//' {} + && \
    find /tmp/build -name "*.md" -exec sed -i 's/\r$//' {} + && \
    find /tmp/build -name "cloudws-*" -exec sed -i 's/\r$//' {} + && \
    chmod +x /tmp/build/scripts/*.sh /tmp/build/scripts/lib/*.sh && \
    chmod +x /tmp/build/scripts/cloudws-toggle-headless /tmp/build/scripts/cloudws-test 2>/dev/null || true && \
    PACKAGES_MD=/tmp/build/PACKAGES.md bash /tmp/build/scripts/build.sh && \
    rm -rf /tmp/build

# Ensure GNOME Software can discover OS updates via rpm-ostree D-Bus bridge.
# Without this package, GNOME Software only shows Flatpak updates.
RUN dnf -y install gnome-software-rpm-ostree && dnf clean all

# System file overlay (configs, systemd units, modprobe.d, dconf, etc.)
# FIX: chmod 644 on systemd units to prevent permission warnings at boot.
RUN --mount=type=bind,from=ctx,source=/system_files,target=/tmp/sf \
    cp -a /tmp/sf/. / && \
    find /etc/systemd/system -name "*.mount" -o -name "*.service" -o -name "*.conf" 2>/dev/null | xargs chmod 644 2>/dev/null || true && \
    dconf update 2>/dev/null || true

LABEL containers.bootc 1
LABEL ostree.bootable 1
RUN bootc container lint
