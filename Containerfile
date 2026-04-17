# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image (v2.3.3)
# ============================================================================
# One image. Every role. Every surface. Every GPU vendor.
#
# Base:     ghcr.io/ublue-os/ucore-hci:stable-nvidia
#           Already ships signed NVIDIA kmods (kmod-nvidia-open) matched to
#           the ucore-hci kernel.
# AMD:      Mesa + ROCm in-image (PACKAGES.md packages-gpu-amd-compute)
# Intel:    intel-compute-runtime + intel-media-driver (packages-gpu-intel-compute)
#
# v2.3.3 fixes v2.3.2's overlay failure at STEP 9/13:
#     cp: cannot overwrite non-directory '/./usr/local' with directory
#     '/ctx/system_files/./usr/local'
#
#   Root cause: ucore-hci (inheriting from Fedora CoreOS) ships /usr/local
#   as a SYMLINK to /var/usrlocal (the OSTree upstream recommendation,
#   documented in bootc filesystem guidance). Our system_files/ has a real
#   directory usr/local/bin/ with 4 scripts. cp -a (and plain tar-pipe)
#   both refuse to overlay a directory onto a symlink.
#
#   Fix: two-stage overlay.
#     1. tar-pipe everything EXCEPT ./usr/local into /
#     2. cp -a the CONTENTS of system_files/usr/local/ into /usr/local/
#        The cp-a-of-contents form follows the symlink: files land at
#        /var/usrlocal/bin/* and the symlink itself is preserved.
#
#   Tested: works for both layouts (symlink dst -> follows; real dir dst
#   -> merges). Safe for Fedora bootc AND ucore-hci.
#
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
LABEL org.opencontainers.image.version="2.3.3"
LABEL containers.bootc="1"

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# ---------------------------------------------------------------------------
# Overlay system_files/ onto the rootfs. Two-stage to handle the
# /usr/local -> /var/usrlocal symlink on ucore/FCOS bases.
# ---------------------------------------------------------------------------
# CloudWS v2.1.6: delegate system_files overlay to the script so the
# /usr/local -> /var/usrlocal symlink on ucore/bootc bases is handled
# correctly (previous inline cp -a failed with 'File exists').
RUN /ctx/scripts/08-system-files-overlay.sh

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
