# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image (v2.3.2)
# ============================================================================
# One image. Every role. Every surface. Every GPU vendor.
#
# Base:     ghcr.io/ublue-os/ucore-hci:stable-nvidia
#           Already ships signed NVIDIA kmods (kmod-nvidia-open) matched to
#           the ucore-hci kernel. That's exactly what an akmods-nvidia COPY
#           layer would provide - they share a build pipeline.
# AMD:      Mesa + ROCm in-image (PACKAGES.md packages-gpu-amd-compute)
# Intel:    intel-compute-runtime + intel-media-driver (packages-gpu-intel-compute)
#
# v2.3.2 removes the broken akmods-nvidia COPY layer attempted in v2.3.0:
#   - buildah does NOT expand `ARG` variables in `COPY --from=<image>:${TAG}`
#     the way Docker BuildKit does. The workflow uses `buildah bud`.
#     v2.3.0's COPY resolved to a literal ":--:" and failed the build.
#   - The image name was wrong anyway: ublue publishes `akmods-nvidia`
#     (with kmod-nvidia-open inside), not `akmods-nvidia-open`.
#   - Fundamentally: ucore-hci:stable-nvidia IS BUILT from akmods-nvidia
#     RPMs. COPY-ing them again on top would be redundant and introduce
#     RPM conflicts, not redundancy. The kernel-mismatch failure mode in
#     v2.2.x is solved by graceful-skip logic in 11-hardware.sh and
#     52-bake-kvmfr.sh, not by a second NVIDIA source.
#
# v2.3.0/v2.3.1 kept:
#   - OVERLAY system_files/ onto / BEFORE build.sh runs. The root-cause fix
#     for every "Unit cloudws-*.service does not exist" warning in v2.2.x.
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
LABEL org.opencontainers.image.version="2.3.2"
LABEL containers.bootc="1"

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# ---------------------------------------------------------------------------
# Overlay system_files/ onto the rootfs BEFORE any script runs. This is the
# single most important change in the v2.3 series - all 40+ systemd units,
# preset entries, dconf profiles, kargs.d TOMLs, greenboot checks, sysctl
# drop-ins, and policy.json come from system_files/. Without this step every
# `systemctl enable cloudws-<foo>.service` downstream silently fails because
# the unit file lives only at /ctx/system_files/.
# ---------------------------------------------------------------------------
RUN cp -a /ctx/system_files/. /

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

# Run the full numbered pipeline (orchestrated by scripts/build.sh).
# CrowdSec sslcacert=  is stripped inside 05-enable-external-repos.sh.
RUN --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/dnf,sharing=locked     \
    set -e; \
    chmod +x /ctx/scripts/build.sh /ctx/scripts/*.sh 2>/dev/null || true; \
    /ctx/scripts/build.sh

RUN bootc container lint

RUN rm -rf /ctx \
 && ostree container commit || true
