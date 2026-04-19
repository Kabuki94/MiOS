#!/usr/bin/env bash
set -eoux pipefail

echo "==> Resolving Podman-Docker symlink conflict..."

# ucore-hci ships with podman-docker by default, which conflicts with moby-engine
# over the /usr/bin/docker symlink. We must explicitly remove the symlink package
# before we can install the real Docker daemon.
dnf remove -y podman-docker

# Install the true Docker engine and compose plugin
dnf install -y moby-engine docker-compose

# Enable the Docker socket to ensure it's available on boot
systemctl enable docker.socket

# Ensure the docker group exists so we can map users to it later via sysusers
groupadd -r docker || true
