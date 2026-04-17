# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image (v2.3.0)
# ============================================================================
# One image. Every role. Every surface. Every GPU vendor.
#
# Base:     ghcr.io/ublue-os/ucore-hci:stable-nvidia
#           ships signed NVIDIA kmods against the ucore-hci kernel.
# Primary:  ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA}[-${NV}]
#           COPY-in layer that provides explicit kernel-matched signed kmods,
#           used when the ucore base kernel-devel doesn't match F44 repos (the
#           6.19.10 vs 6.19.12 mismatch that broke v2.2.x). 34-gpu-detect.sh at
#           runtime picks whichever set matches `uname -r`.
# AMD:      Mesa + ROCm in-image (PACKAGES.md packages-gpu-amd-compute)
# Intel:    intel-compute-runtime + intel-media-driver (packages-gpu-intel-compute)
#
# v2.3.0 deltas vs v2.2.x:
#   - OVERLAY system_files/ onto / BEFORE build.sh runs. Fixes the root cause
#     of every "Unit cloudws-*.service does not exist" warning. See scripts
#     42/45/46/47/48/98 that all assume units are present.
#   - COPY akmods-nvidia-open kmods into /ctx/nv-akmods; 02-kernel.sh or
#     11-hardware.sh can install the RPMs when the base kernel-devel doesn't
#     match. The base modules remain as fallback; 34-gpu-detect.sh chooses.
#   - STRIP CrowdSec sslcacert= (handled in 05-enable-external-repos.sh)
#   - Promote composefs from "enabled=yes" to "enabled=verity" via
#     system_files/usr/lib/ostree/prepare-root.conf.
#   - cosign keyless signing via .github/workflows/build-sign.yml (already
#     scaffolded); /etc/containers/policy.json enforces sigstore for the
#     ghcr.io/kabuki94/cloudws-bootc and ghcr.io/ublue-os repos.
#
# Roles:  desktop | k3s-master | k3s-worker | ha-node | hybrid | headless
#         Set via /etc/cloudws/role.conf or kernel cmdline cloudws.role=...
#         Applied by cloudws-role.service on boot.
# ============================================================================

ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia

# Tags for the akmods COPY layer. These MUST match the ucore-hci base kernel
# series; mismatched tags produce kmods that won't load. The "main" flavor and
# "rawhide" suffix track ucore-hci's own release cadence. NV_MAJOR 580 is the
# current Fedora Rawhide NVIDIA branch as of April 2026; bump when NVIDIA ships
# a new major (check `dnf5 info akmod-nvidia` in ucore-hci for the target).
ARG KERNEL_FLAVOR=main
ARG FEDORA=rawhide
ARG NV_MAJOR=580

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
LABEL org.opencontainers.image.version="2.3.0"
LABEL containers.bootc="1"

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# ---------------------------------------------------------------------------
# NVIDIA akmods COPY layer - kernel-matched signed kmods from upstream ublue.
# The RPMs land at /ctx/nv-akmods/; 11-hardware.sh decides whether to install
# them based on whether `uname -r` from the base matches what's in F44 repos.
# If the base image shape changes (new kernel, new NV major), bump ARG NV_MAJOR
# and rebuild. We intentionally do NOT COPY from the :latest tag here - that
# would desync from the kernel in the base on every rebuild.
# ---------------------------------------------------------------------------
COPY --from=ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA}-${NV_MAJOR} /rpms /ctx/nv-akmods/open/
COPY --from=ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA} /rpms /ctx/nv-akmods/common/

# ---------------------------------------------------------------------------
# Overlay system_files/ onto the rootfs BEFORE any script runs. This is the
# single most important change in v2.3.0 - all 40+ systemd units, preset
# entries, dconf profiles, kargs.d TOMLs, greenboot checks, sysctl drop-ins,
# and policy.json come from system_files/. Without this step every `systemctl
# enable cloudws-<foo>.service` downstream silently fails because the unit
# file lives only at /ctx/system_files/.
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
