# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image
# ============================================================================
# One image. Every role. Every surface.
#
# Bases:    quay.io/fedora/fedora-bootc:rawhide   (CLOUDWS_BASE=fedora)
#           ghcr.io/ublue-os/ucore-hci:stable-nvidia (CLOUDWS_BASE=ucore, default)
#
# Targets:  bare metal, Hyper-V VHDX, QEMU/libvirt qcow2, WSL2 tarball,
#           Anaconda ISO, GHCR OCI push, Podman machine backend, K3s node.
#
# Roles:    desktop | k3s-master | k3s-worker | ha-node | hybrid | headless
#           Set via /etc/cloudws/role.conf or kernel cmdline (cloudws.role=...)
#           Applied by cloudws-role.service on boot.
# ============================================================================

ARG FEDORA=rawhide
ARG KERNEL_FLAVOR=main
ARG NV_MAJOR=580
ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia

# ----------------------------------------------------------------------------
# ctx stage: build context only (scripts, system_files, package manifests)
# ----------------------------------------------------------------------------
FROM scratch AS ctx
COPY scripts/        /ctx/scripts/
COPY system_files/   /ctx/system_files/
COPY PACKAGES.md     /ctx/PACKAGES.md
COPY bib-configs/    /ctx/bib-configs/

# ----------------------------------------------------------------------------
# akmod source stages (pre-signed kernel modules from ublue-os)
# ----------------------------------------------------------------------------
FROM ghcr.io/ublue-os/akmods-nvidia-open:${KERNEL_FLAVOR}-${FEDORA}-${NV_MAJOR} AS akmods-nvidia
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA}                        AS akmods-common
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_FLAVOR}-${FEDORA}                  AS akmods-extra

# ----------------------------------------------------------------------------
# main stage
# ----------------------------------------------------------------------------
FROM ${BASE_IMAGE}

ARG FEDORA
ARG KERNEL_FLAVOR
ARG NV_MAJOR

LABEL org.opencontainers.image.title="CloudWS-bootc"
LABEL org.opencontainers.image.description="Unified immutable cloud-native workstation OS (desktop/k3s/ha/hybrid)"
LABEL org.opencontainers.image.source="https://github.com/Kabuki94/CloudWS-bootc"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL containers.bootc="1"

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# Pre-signed akmod RPMs available as mount points (not copied yet;
# scripts/41-akmods-copy.sh handles selective install)
COPY --from=akmods-nvidia /rpms /tmp/akmods-nvidia
COPY --from=akmods-common /rpms /tmp/akmods-common
COPY --from=akmods-extra  /rpms /tmp/akmods-extra

# Ensure no weak deps, explicit architecture, no base kernel upgrade
RUN mkdir -p /etc/dnf \
 && printf '%s\n' \
      '[main]' \
      'install_weak_deps=False' \
      'tsflags=nodocs' \
      'defaultyes=True' \
      'clean_requirements_on_remove=True' \
      'protect_running_kernel=True' \
    > /etc/dnf/dnf.conf

# Run the full numbered pipeline
RUN --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/dnf,sharing=locked     \
    set -e; \
    chmod +x /ctx/scripts/build.sh /ctx/scripts/*.sh || true; \
    /ctx/scripts/build.sh

# Lint the result before publishing
RUN bootc container lint

# Clean up build context and temp RPM stashes
RUN rm -rf /tmp/akmods-nvidia /tmp/akmods-common /tmp/akmods-extra \
 && rm -rf /ctx \
 && ostree container commit || true