# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image (v2.2.4)
# ============================================================================
# One image. Every role. Every surface.
#
# Base: ghcr.io/ublue-os/ucore-hci:stable-nvidia already ships signed NVIDIA
# kmods (via ublue-os/ucore-kmods at ucore build time). No external akmod
# COPY stages - they would violate project principle "Only external images
# ever pulled are upstream bases" AND require kernel matching that isn't
# guaranteed with rawhide akmods.
#
# Roles:  desktop | k3s-master | k3s-worker | ha-node | hybrid | headless
#         Set via /etc/cloudws/role.conf or kernel cmdline cloudws.role=...
#         Applied by cloudws-role.service on boot.
# ============================================================================

ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia

# ----------------------------------------------------------------------------
# ctx stage: build context (scripts, system_files, manifests)
# ----------------------------------------------------------------------------
FROM scratch AS ctx
COPY scripts/        /ctx/scripts/
COPY system_files/   /ctx/system_files/
COPY PACKAGES.md     /ctx/PACKAGES.md
COPY VERSION         /ctx/VERSION
COPY bib-configs/    /ctx/bib-configs/

# ----------------------------------------------------------------------------
# main stage
# ----------------------------------------------------------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="CloudWS-bootc"
LABEL org.opencontainers.image.description="Unified immutable cloud-native workstation OS (desktop/k3s/ha/hybrid)"
LABEL org.opencontainers.image.source="https://github.com/Kabuki94/CloudWS-bootc"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="2.2.4"
LABEL containers.bootc="1"

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# DNF defaults: no weak deps, no docs, protect running kernel
RUN mkdir -p /etc/dnf \
 && printf '%s\n' \
      '[main]' \
      'install_weak_deps=False' \
      'tsflags=nodocs' \
      'defaultyes=True' \
      'clean_requirements_on_remove=True' \
      'protect_running_kernel=True' \
    > /etc/dnf/dnf.conf

# Run the full numbered pipeline (orchestrated by scripts/build.sh)
RUN --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/dnf,sharing=locked     \
    set -e; \
    chmod +x /ctx/scripts/build.sh /ctx/scripts/*.sh 2>/dev/null || true; \
    /ctx/scripts/build.sh

RUN bootc container lint

RUN rm -rf /ctx \
 && ostree container commit || true