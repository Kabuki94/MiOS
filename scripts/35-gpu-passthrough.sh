#!/usr/bin/env bash
# ============================================================================
# CloudWS-bootc v2.3.4 - 35-gpu-passthrough.sh
# ----------------------------------------------------------------------------
# Installs per-vendor systemd units, udev rules, tmpfiles, sysusers, kargs.d,
# and SELinux booleans for universal GPU container passthrough on bootc.
#
# Runs AFTER 34-gpu-detect.sh (which handles the VM NVIDIA-blacklist dance
# via its own /usr/lib/systemd/system/cloudws-gpu-detect.service).
#
# v2.3.4: renamed cloudws-gpu-detect.service -> cloudws-gpu-status.service
# at both the install target and the multi-user.target.wants symlink so we
# no longer clobber 34-gpu-detect.sh's unit. Both services now coexist.
# Pure build-time installer: does NOT inspect host hardware.
# ============================================================================
set -euo pipefail
IFS=$'\n\t'

log() { printf '[35-gpu-passthrough] %s\n' "$*"; }
log "Starting GPU passthrough plumbing install"

# Containerfile COPY destination for build-context assets.
SRC_ROOT="${SRC_ROOT:-/ctx}"

# ----------------------------------------------------------------------------
# Systemd units (per-vendor + umbrella status)
# ----------------------------------------------------------------------------
install -d -m 0755 /usr/lib/systemd/system
install -m 0644 "${SRC_ROOT}/systemd/cloudws-gpu-status.service"  /usr/lib/systemd/system/
install -m 0644 "${SRC_ROOT}/systemd/cloudws-gpu-nvidia.service"  /usr/lib/systemd/system/
install -m 0644 "${SRC_ROOT}/systemd/cloudws-gpu-amd.service"     /usr/lib/systemd/system/
install -m 0644 "${SRC_ROOT}/systemd/cloudws-gpu-intel.service"   /usr/lib/systemd/system/

# ----------------------------------------------------------------------------
# NVIDIA upstream nvidia-cdi-refresh.service drop-in
# Works around NVIDIA/nvidia-container-toolkit#1735 ordering cycle introduced
# in v1.19.0 (After=multi-user.target). Only installed if the toolkit is
# present in the image (i.e. CloudWS-2 ucore-hci:stable-nvidia).
# ----------------------------------------------------------------------------
if rpm -q nvidia-container-toolkit >/dev/null 2>&1; then
  log "nvidia-container-toolkit present; installing ordering drop-in"
  install -d -m 0755 /usr/lib/systemd/system/nvidia-cdi-refresh.service.d
  install -m 0644 "${SRC_ROOT}/systemd/nvidia-cdi-refresh.service.d/10-cloudws-ordering.conf" \
    /usr/lib/systemd/system/nvidia-cdi-refresh.service.d/
else
  log "nvidia-container-toolkit not in image; skipping NVIDIA drop-in"
fi

# ----------------------------------------------------------------------------
# udev rules (pinned for determinism across Rawhide kernel bumps)
# ----------------------------------------------------------------------------
install -d -m 0755 /usr/lib/udev/rules.d
install -m 0644 "${SRC_ROOT}/udev/99-cloudws-gpu.rules" /usr/lib/udev/rules.d/

# ----------------------------------------------------------------------------
# tmpfiles.d / sysusers.d
# ----------------------------------------------------------------------------
install -d -m 0755 /usr/lib/tmpfiles.d /usr/lib/sysusers.d
install -m 0644 "${SRC_ROOT}/tmpfiles.d/cloudws-gpu.conf"    /usr/lib/tmpfiles.d/
install -m 0644 "${SRC_ROOT}/sysusers.d/50-cloudws-gpu.conf" /usr/lib/sysusers.d/

# ----------------------------------------------------------------------------
# Enable units via symlink (Containerfile-safe; `systemctl enable` cannot run
# in a bootc build because there is no PID 1 / dbus during image assembly).
# ----------------------------------------------------------------------------
WANTS=/usr/lib/systemd/system/multi-user.target.wants
install -d -m 0755 "${WANTS}"
ln -sf ../cloudws-gpu-status.service "${WANTS}/cloudws-gpu-status.service"
ln -sf ../cloudws-gpu-nvidia.service "${WANTS}/cloudws-gpu-nvidia.service"
ln -sf ../cloudws-gpu-amd.service    "${WANTS}/cloudws-gpu-amd.service"
ln -sf ../cloudws-gpu-intel.service  "${WANTS}/cloudws-gpu-intel.service"

# Enable the upstream NVIDIA path unit where the toolkit shipped it.
if [[ -f /usr/lib/systemd/system/nvidia-cdi-refresh.path ]]; then
  ln -sf ../nvidia-cdi-refresh.path "${WANTS}/nvidia-cdi-refresh.path"
  log "Enabled nvidia-cdi-refresh.path"
fi

# ----------------------------------------------------------------------------
# SELinux: enable container_use_devices boolean so containers can touch
# /dev/kfd and /dev/dri with the default container_t domain. This is the
# minimal-privilege path for AMD/Intel compute - NOT container_runtime_t.
#
# Baking via `semanage boolean` at build time is best-effort; on images where
# the SELinux policy store is not mutable during build, the runtime
# cloudws-gpu-status.service sets it again (non-persistent) at every boot.
# ----------------------------------------------------------------------------
if command -v semanage >/dev/null 2>&1 && [[ -d /etc/selinux/targeted ]]; then
  if semanage boolean -m --on container_use_devices 2>/dev/null; then
    log "SELinux boolean container_use_devices persisted at build time"
  else
    log "semanage not operational in build; runtime service will handle it"
  fi
fi

# ----------------------------------------------------------------------------
# kargs.d
# ----------------------------------------------------------------------------
install -d -m 0755 /usr/lib/bootc/kargs.d
install -m 0644 "${SRC_ROOT}/kargs.d/02-cloudws-gpu.toml" /usr/lib/bootc/kargs.d/

log "GPU passthrough plumbing installed successfully"