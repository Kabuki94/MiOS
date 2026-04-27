# syntax=docker/dockerfile:1.9
# ============================================================================
# MiOS - Unified Image (v2.1.0)
# ============================================================================
# One image. Every role. Every surface. Every GPU vendor.
#
# Base:     Controlled by MIOS_BASE_IMAGE in .env.mios
#           Default: ghcr.io/ublue-os/ucore-hci:stable-nvidia
#           Already ships signed NVIDIA kmods (kmod-nvidia-open) matched to
#           the ucore-hci kernel.
# AMD:      Mesa + ROCm in-image (PACKAGES.md packages-gpu-amd-compute)
# Intel:    intel-compute-runtime + intel-media-driver (packages-gpu-intel-compute)
#
# v2.1.0 fixes the docs-restructure fallout from commit 0eff8d8:
#
#   1) PACKAGES.md was relocated from the repo root to specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md
#      together with the other long-form docs. The ctx stage still copied
#      from the old path, so every subsequent build failed at the
#      build-context stage with
#         COPY PACKAGES.md /ctx/PACKAGES.md  -> no such file
#      The COPY directive below is now `specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md -> /ctx/PACKAGES.md`
#      so `automation/lib/packages.sh` (unchanged, still reads /ctx/PACKAGES.md)
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
# v2.1.0 fixed v2.1.0's three runtime failures:
#
#   1) bootc container lint REJECTED 01-mios-vm-boot.toml with
#        Linting: Unexpected runtime error running lint bootc-kargs:
#        Parsing 01-mios-vm-boot.toml
#      The file used the Copilot-flavoured
#          [kargs]
#          delete = [...]
#          append = [...]
#      layout. bootc kargs.d only accepts a flat root-level
#          kargs = [ ... ]
#      array; there is NO delete mechanism and NO [kargs] table header.
#      All content was already provided by 00-mios.toml and
#      10-mios-verbose.toml (systemd.show-status=true, serial console,
#      plymouth.enable=0), so the file is deleted outright. The
#      "strip quiet/rhgb" intent remains achievable because plymouth is
#      disabled and systemd.show-status=true forces status output
#      regardless of quiet/rhgb surviving in the base image cmdline.
#
#   2) 35-gpu-passthrough.sh FAILED:
#        install: cannot stat '/ctx/systemd/mios-gpu-detect.service'
#      The ctx stage copied automation/, overlay/, PACKAGES.md, VERSION,
#      and bib-configs/, but NOT the top-level passthrough overlay dirs
#      (systemd/, udev/, tmpfiles.d/, sysusers.d/, kargs.d/). Those are
#      now included below.
#
#   3) Name collision between 34-gpu-detect.sh (heredoc-writes
#      mios-gpu-detect.service with VM NVIDIA-blacklist + hardware-
#      renderer + RTX 50-series detection logic) and
#      systemd/mios-gpu-detect.service (v2.1.0 passthrough-umbrella
#      status dumper). Both targeted /usr/lib/systemd/system/
#      mios-gpu-detect.service. Renamed the umbrella to
#      mios-gpu-status.service so both coexist; 35-gpu-passthrough.sh
#      updated to match.
#
# v2.1.0 fixed overlay failure at STEP 9/13 (/usr/local symlink) - kept.
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
COPY automation/           /ctx/automation/
COPY overlay/      /ctx/overlay/
# v2.1.0: PACKAGES.md moved to specs/engineering/ during the artifact reorganization.
# Re-path the COPY so /ctx/PACKAGES.md (the path packages.sh reads) stays stable.
COPY specs/engineering/2026-04-26-Artifact-ENG-001-Packages.md   /ctx/PACKAGES.md
COPY VERSION            /ctx/VERSION
COPY config/artifacts/       /ctx/bib-configs/
COPY tools/             /ctx/tools/

# ----------------------------------------------------------------------------
# main stage
# ----------------------------------------------------------------------------
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="MiOS"
LABEL org.opencontainers.image.description="Unified immutable cloud-native workstation OS (desktop/k3s/ha/hybrid)"
LABEL org.opencontainers.image.source="https://github.com/Kabuki94/mios"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="v2.1.0"
LABEL containers.bootc="1"
LABEL ostree.bootable="1"

# Set /sbin/init as the default command for bootc compatibility
CMD ["/sbin/init"]

# Build-time user provisioning — injected by mios-build-local.ps1 via --build-arg.
# 31-user.sh reads these as MIOS_USER / MIOS_PASSWORD_HASH env vars.
# ARG values do NOT persist into the final image (unlike ENV).
ARG MIOS_USER=mios
ARG MIOS_PASSWORD_HASH=
ARG MIOS_HOSTNAME=mios
ARG MIOS_FLATPAKS=

# Build context mounted read-only
COPY --from=ctx /ctx /ctx

# Inject flatpaks into the install list if provided
RUN if [[ -n "${MIOS_FLATPAKS}" ]]; then \
        echo "${MIOS_FLATPAKS}" | tr ',' '\n' > /ctx/overlay/usr/share/mios/flatpak-list; \
    fi

# Pre-pull images for Logically Bound Images (LBI)
# This ensures bootc-image-builder can resolve them during disk assembly.
# Note: we use || true to prevent build failure if registry is temporarily down.
RUN podman pull docker.io/postgres:15 || true \
 && podman pull docker.io/ollama/ollama:latest || true \
 && podman pull docker.io/guacamole/guacamole:latest || true \
 && podman pull docker.io/guacamole/guacd:latest || true \
 && podman pull quay.io/ceph/ceph:latest || true

# ---------------------------------------------------------------------------
# Overlay overlay/ onto the rootfs. Two-stage to handle the
# /usr/local -> /var/usrlocal symlink on ucore/FCOS bases.
# ---------------------------------------------------------------------------
# MiOS v2.1.0: delegate system_files overlay to the script so the
# /usr/local -> /var/usrlocal symlink on ucore/bootc bases is handled
# correctly (previous inline cp -a failed with 'File exists').
RUN bash /ctx/automation/08-system-files-overlay.sh

# Run the full numbered pipeline (orchestrated by automation/build.sh).
# CrowdSec sslcacert=  is stripped inside 05-enable-external-repos.sh.
RUN --mount=type=cache,dst=/var/cache/libdnf5,sharing=locked \
    --mount=type=cache,dst=/var/cache/dnf,sharing=locked     \
    set -e; \
    chmod +x /ctx/automation/build.sh /ctx/automation/*.sh 2>/dev/null || true; \
    /ctx/automation/build.sh && \
    /ctx/automation/18-apply-boot-fixes.sh && \
    /ctx/automation/19-k3s-selinux.sh && \
    /ctx/automation/20-fapolicyd-trust.sh && \
    /ctx/automation/21-moby-engine.sh && \
    /ctx/automation/22-freeipa-client.sh && \
    /ctx/automation/23-uki-render.sh && \
    /ctx/automation/25-firewall-ports.sh && \
    /ctx/automation/26-gnome-remote-desktop.sh && \
    /ctx/automation/37-ollama-prep.sh
# Preserve build logs before cleanup (dracut-live + squashfs-tools already in PACKAGES.md containers section)
RUN mkdir -p /usr/lib/mios/logs \
 && cp -v /var/log/dnf5.log* /var/log/hawkey.log /usr/lib/mios/logs/ 2>/dev/null || true

# MANDATORY CLEANUP for bootc container lint
# Purge all logs and temporary files that violate /var immutability rules.
# (Main logs are preserved in /usr/lib/mios/logs)
RUN rm -rf /var/log/* /var/tmp/* /var/cache/dnf/* /var/cache/libdnf5/* /tmp/* \
 && find /run -mindepth 1 -maxdepth 1 ! -name 'secrets' -exec rm -rf {} + 2>/dev/null || true

# Install bootc bash completions so `bootc <TAB>` works on deployed systems
RUN bootc completion bash > /etc/bash_completion.d/bootc

# ── systemd-sysext consolidation ──────────
# Squash granular extensions into a monolithic accelerator image to prevent
# 'overlayfs: maximum fs stacking depth exceeded' errors.
RUN mkdir -p /usr/lib/extensions/source \
 && chmod +x /ctx/tools/mios-sysext-pack.sh \
 && /ctx/tools/mios-sysext-pack.sh /usr/lib/extensions/source || true

RUN bootc container lint
RUN rm -rf /ctx \
 && ostree container commit
