#!/usr/bin/env bash
# Normalize to LF line endings (fixes SC1017)
set -euo pipefail

echo "==> Installing moby-engine (Docker) alongside Podman..."

# moby-engine conflicts with podman-docker over /usr/bin/docker. Use --allowerasing
# to let dnf resolve the conflict without an explicit remove (§3.9: no dnf remove).
dnf install -y --allowerasing moby-engine docker-compose

# Enable the Docker socket to ensure it's available on boot
systemctl enable docker.socket

# Ensure the docker group exists so we can map users to it later via sysusers
groupadd -r docker || true
