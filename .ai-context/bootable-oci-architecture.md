# Bootable OCI Images, Bootc, & uBlue Atomic Desktops

This document provides technical context on bootable OCI images, the `bootc` tooling, and the Universal Blue (uBlue) ecosystem. This architecture underpins the CloudWS-bootc project.

## Core Concepts

### 1. Bootable OCI Images ("Image Mode" OS)
Unlike traditional Linux distributions where an installer writes individual packages (RPMs, DEBs) to a disk, an "image mode" OS packages the entire root filesystem—including the Linux kernel, initramfs, and systemd—into a standard OCI container image (the same format used by Docker/Podman).

*   **Build Phase:** A `Containerfile` (Dockerfile) defines the OS state.
*   **Delivery:** The OS is pushed to an OCI registry (e.g., GitHub Container Registry, Quay.io).
*   **Execution:** A physical or virtual machine boots directly into the state defined by that container image.

### 2. Technical Architecture: `bootc` + `ostree`
`bootc` is the client-side tool that bridges the container world with the bare-metal/VM world. It is the successor to `rpm-ostree`.

*   **Transactional Updates:** Under the hood, `bootc` uses `libostree` ("Git for operating system binaries"). Updates are atomic. `bootc` downloads the new image layer in the background, stages it alongside the current system, and switches to it upon reboot.
*   **Rollbacks:** Because two deployments (current and staged/previous) exist on disk, users can roll back to a known-good state instantly via the GRUB boot menu if an update fails.
*   **Immutability:** To guarantee the container image's integrity, the system partition (`/usr`) is mounted as read-only.
*   **Persistent State:** User data (`/var`, `/home`) and system configuration (`/etc`) are persistent. `bootc` performs a three-way merge to ensure local `/etc` changes survive image updates.

#### Common `bootc` Commands
*   `bootc status`: Check the current deployment and staged updates.
*   `bootc upgrade`: Fetch and stage the latest image from the registry.
*   `bootc switch <image-ref>`: Rebase the entire OS to a completely different OCI image.

### 3. Universal Blue (uBlue) Integration
Universal Blue is a community project that builds specialized desktop images on top of Fedora Atomic base images using GitHub Actions. Examples include Bazzite (gaming) and Bluefin (developer-focused).

*   **Layering:** uBlue images take a base Fedora image and use container tools to pre-install drivers (NVIDIA, AMD), codecs, and desktop environments.
*   **Extensibility:** Because the OS is just a `Containerfile`, users (like the CloudWS-bootc project) can use a uBlue image as a `FROM` target, add their specific tools or scripts, and push their own custom OS image.

### 4. Generating Installation Media (`bootc-image-builder`)
An OCI container image cannot boot bare metal on its own; it must be converted into a disk format with a bootloader, partition table, and filesystem.

*   **`bootc-image-builder`**: A specialized tool (often run via Podman) that takes a bootable OCI image from a registry and outputs an ISO, QCOW2 (for VMs), RAW, or AMI disk image.
*   **Configuration:** `bootc-image-builder` accepts a `config.toml` to inject users, SSH keys, or passwords into the generated disk image, which is necessary because the base OCI image is usually locked down.

## Relevance to CloudWS-bootc
CloudWS-bootc utilizes this exact paradigm:
1.  It defines a `Containerfile` based on `ghcr.io/ublue-os/ucore-hci`.
2.  It layers scripts, configurations, and packages (`scripts/`, `system_files/`) into the image.
3.  It leverages GitHub Actions (`.github/workflows/build.yml`) to build and push the image to GHCR.
4.  It uses `bootc-image-builder` (via the `Justfile`) to generate bootable media (ISO, RAW, VHD, WSL tarball) for deployment.