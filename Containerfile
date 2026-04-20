# syntax=docker/dockerfile:1.9
# ============================================================================
# CloudWS-bootc - Unified Image (v2.3.5)
# ============================================================================
# One image. Every role. Every surface. Every GPU vendor.
#
# Base:     ghcr.io/ublue-os/ucore-hci:stable-nvidia
#           Already ships signed NVIDIA kmods (kmod-nvidia-open) matched to
#           the ucore-hci kernel.
# AMD:      Mesa + ROCm in-image (PACKAGES.md packages-gpu-amd-compute)
# Intel:    intel-compute-runtime + intel-media-driver (packages-gpu-intel-compute)
#
# v2.3.5 fixes the docs-restructure fallout from commit 0eff8d8:
#
#   1) PACKAGES.md was relocated from the repo root to docs/PACKAGES.md
#      together with the other long-form docs. The ctx stage still copied
#      from the old path, so every subsequent build failed at the
#      build-context stage with
#         COPY PACKAGES.md /ctx/PACKAGES.md  -> no such file
#      The COPY directive below is now `docs/PACKAGES.md -> /ctx/PACKAGES.md`
#      so `scripts/lib/packages.sh` (unchanged, still reads /ctx/PACKAGES.md)
#      keeps working without modification. No other moved doc is consumed
#      by the build pipeline — only PACKAGES.md had to be re-pathed.
#
#   2) ARCHITECTURAL PURITY FIX: Removed redundant top-level directories
#      (systemd/, udev/, tmpfiles.d/, sysusers.d/, kargs.d/). All files
#      are now delivered via the system_files overlay. The ctx stage
#      no longer performs redundant COPY commands, and 35-gpu-passthrough.sh
#      no longer performs manual 'install' calls. This eliminates the
#      "cannot stat" failures caused by path desynchronization.
#
# v2.3.4 fixed v2.3.3's three runtime failures:
#
#   1) bootc container lint REJECTED 01-cloudws-vm-boot.toml with
#        Linting: Unexpected runtime error running lint bootc-kargs:
#        Parsing 01-cloudws-vm-boot.toml
#      The file used the Copilot-flavoured
#          [kargs]
#          delete = [...]
#          append = [...]
#      layout. bootc kargs.d only accepts a flat root-level
#          kargs = [ ... ]
#      array; there is NO delete mechanism and NO [kargs] table header.
#      All content was already provided by 00-cloudws.toml and
#      10-cloudws-verbose.toml (systemd.show-status=true, serial console,
#      plymouth.enable=0), so the file is deleted outright. The
#      "strip quiet/rhgb" intent remains achievable because plymouth is
#      disabled and systemd.show-status=true forces status output
#      regardless of quiet/rhgb surviving in the base image cmdline.
#
#   2) 35-gpu-passthrough.sh FAILED:
#        install: cannot stat '/ctx/systemd/cloudws-gpu-detect.service'
#      The ctx stage copied scripts/, system_files/, PACKAGES.md, VERSION,
#      and bib-configs/, but NOT the top-level passthrough overlay dirs
#      (systemd/, udev/, tmpfiles.d/, sysusers.d/, kargs.d/). Those are
#      now included below.
#
#   3) Name collision between 34-gpu-detect.sh (heredoc-writes
#      cloudws-gpu-detect.service with VM NVIDIA-blacklist + hardware-
#      renderer + RTX 50-series detection logic) and
#      systemd/cloudws-gpu-detect.service (v2.1.5 passthrough-umbrella
#      status dumper). Both targeted /usr/lib/systemd/system/
#      cloudws-gpu-detect.service. Renamed the umbrella to
#      cloudws-gpu-status.service so both coexist; 35-gpu-passthrough.sh
#      updated to match.
#
# v2.3.3 fixed overlay failure at STEP 9/13 (/usr/local symlink) - kept.
# ============================================================================

# Renovate's customManager regex (renovate.json) rewrites this line to
#   ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia@sha256:<digest>
# on its first run. Until then the tag-only default is valid and CI builds
# resolve the current digest at pull time.
ARG BASE_IMAGE=ghcr.io/ublue-os/ucore-hci:stable-nvidia

# ----------------------------------------------------------------------------
# ctx stage: build context (scripts, system_files, manifests, overlay dirs)
# ----------------------------------------------------------------------------
FROM scratch AS ctx
COPY scripts/           /ctx/scripts/
COPY system_files/      /ctx/system_files/
# v2.3.5: PACKAGES.md moved to docs/ during the docs consolidation; re-path
# the COPY so /ctx/PACKAGES.md (the path packages.sh reads) stays stable.
COPY docs/PACKAGES.md   /ctx/PACKAGES.md
COPY VERSION            /ctx/VERSION
COPY bib-configs/       /ctx/bib-configs/

# ----------------------------------------------------------------------------
# main stage
# ----------------------------------------------------------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="CloudWS-bootc"
LABEL org.opencontainers.image.description="Unified immutable cloud-native workstation OS (desktop/k3s/ha/hybrid)"
LABEL org.opencontainers.image.source="https://github.com/Kabuki94/CloudWS-bootc"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="2.3.5"
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
RUN bash /ctx/scripts/08-system-files-overlay.sh

# DNF defaults: no weak deps, no docs, protect running kernel, speed optimizations
RUN mkdir -p /etc/dnf \
 && printf '%s\n' \
      '[main]' \
      'install_weak_deps=False' \
      'tsflags=nodocs' \
      'defaultyes=True' \
      'clean_requirements_on_remove=True' \
      'protect_running_kernel=True' \
      'max_parallel_downloads=20' \
      'fastestmirror=True' \
    > /etc/dnf/dnf.conf

# Run the full numbered pipeline (orchestrated by scripts/build.sh).
# CrowdSec sslcacert=  is stripped inside 05-enable-external-repos.sh.
RUN --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/dnf,sharing=locked     \
    set -e; \
    # CI fallback: remove INJ_U/INJ_HASH placeholders used by Windows build script
    sed -i 's/INJ_U/cloudws/g' /ctx/scripts/31-user.sh 2>/dev/null || true; \
    sed -i '/INJ_HASH/d' /ctx/scripts/31-user.sh 2>/dev/null || true; \
    chmod +x /ctx/scripts/build.sh /ctx/scripts/*.sh 2>/dev/null || true; \
    /ctx/scripts/build.sh && \
    /ctx/scripts/18-apply-boot-fixes.sh && \
    /ctx/scripts/19-k3s-selinux.sh && \
    /ctx/scripts/20-fapolicyd-trust.sh && \
    /ctx/scripts/21-moby-engine.sh && \
    /ctx/scripts/22-freeipa-client.sh && \
    /ctx/scripts/23-uki-render.sh && \
    /ctx/scripts/24-cockpit-config.sh && \
    /ctx/scripts/25-firewall-ports.sh && \
    /ctx/scripts/26-gnome-remote-desktop.sh

# Ensure dracut-live + squashfs-tools for the ISO artifact build leg
RUN dnf install -y dracut-live squashfs-tools \
 && dnf clean all

RUN bootc container lint
RUN rm -rf /ctx \
 && ostree container commit
