# Self-Build Mode Guide

CloudWS-bootc is a self-replicating OS — the published image can be used as the builder for the next generation. This document explains the self-build architecture and when to use each mode.

## How Self-Build Works

CloudWS ships all the tools needed to rebuild itself: Podman, Buildah, bootc, and bootc-image-builder (BIB) are all baked into the image. This means you can boot a running CloudWS system and use it to build the next version, without needing a separate build environment.

The build chain is:

```
CloudWS v1.3.0 (running) → builds → CloudWS v1.3.0 (OCI image)
                                        ↓
                                  Rechunk → Sign → Push to GHCR
                                        ↓
                              CloudWS v1.3.0 (running via bootc upgrade)
                                        ↓
                                  builds → CloudWS v1.3.0 ...
```

## Build Modes

### Mode 1: CI/CD (GitHub Actions) — Recommended

The GitHub Actions workflow automatically builds, rechunks, signs, and pushes the image on every commit to `main` and on a weekly schedule. This is the recommended approach for production use.

```bash
# Users receive updates via:
sudo bootc upgrade
```

No local build infrastructure needed. The CI runner is an Ubuntu 24.04 GitHub-hosted runner.

### Mode 2: Windows Local Build (cloud-ws.ps1)

For local development and testing on Windows with Podman Desktop:

```powershell
# Run the 5-phase orchestrator
.\cloud-ws.ps1
```

This creates a dedicated `cloudws-builder` Podman machine, builds the OCI image, rechunks it, generates disk images (RAW, VHDX, WSL, ISO), and optionally pushes to GHCR. Phase by phase:

1. **Phase 0**: Prompts for username, password, LUKS passphrase, registry credentials
2. **Phase 1**: Creates the `cloudws-builder` Podman machine (rootful, all cores, all RAM, 250 GB disk)
3. **Phase 2**: Injects credentials into `99-overrides.sh`, runs `podman build`, rechunks, restores placeholders
4. **Phase 3**: Generates disk images via BIB (RAW → VHDX, WSL tarball, Anaconda ISO)
5. **Phase 4**: Pushes to GHCR, sets package public
6. **Phase 5**: Restores default Podman machine, prints report

### Mode 3: Linux Local Build (Justfile)

For local development on a Linux system (including a running CloudWS):

```bash
# Full build
just build

# Build + rechunk
just build rechunk

# Build + all disk images
just all

# Individual targets
just raw       # RAW disk image
just iso       # Anaconda ISO
just vhd       # VHDX for Hyper-V
just wsl       # WSL2 tarball
just push      # Push to GHCR
just lint      # Run bootc container lint
just clean     # Clean build artifacts
```

### Mode 4: Self-Build (running CloudWS builds next CloudWS)

Boot into a running CloudWS system and build from source:

```bash
# Clone the repo
git clone https://github.com/Kabuki94/CloudWS-bootc.git
cd CloudWS-bootc

# Build the OCI image (rootful Podman required)
sudo podman build --no-cache -t localhost/cloudws-bootc:dev .

# Validate
sudo podman run --rm localhost/cloudws-bootc:dev bootc container lint

# Rechunk for optimal delta updates
sudo bootc-base-imagectl rechunk --max-layers 67 \
  localhost/cloudws-bootc:dev \
  localhost/cloudws-bootc:rechunked

# Test locally: switch to the locally-built image
sudo bootc switch --transport containers-storage localhost/cloudws-bootc:rechunked
sudo systemctl reboot
```

## Bootstrapping the First Image

If you're starting from scratch (no existing CloudWS image):

1. Install Podman on any Linux system (Fedora, Ubuntu, etc.) or use Podman Desktop on Windows
2. Clone the repo and run `podman build` (or `cloud-ws.ps1` on Windows)
3. The Containerfile pulls `ghcr.io/ublue-os/ucore-hci:stable-nvidia` (CloudWS-2 primary, pre-signed NVIDIA kmods) or `quay.io/fedora/fedora-bootc:rawhide` (CloudWS-1, akmod-built drivers) as the base — no prior CloudWS image needed
4. Deploy the resulting image to your target (bare metal via ISO, Hyper-V via VHDX, etc.)
5. Subsequent builds can use the running CloudWS itself (self-build mode)

## Verifying Self-Build Capability

To confirm that a running CloudWS image can build the next generation:

```bash
# Check required tools are present
which podman buildah bootc bootc-image-builder

# Check Podman can build (rootful)
sudo podman info | grep -E "rootless|graphRoot"

# Check disk space (need ~50 GB free for build)
df -h /var/lib/containers

# Test a minimal build
sudo podman build --no-cache -t test-build . && echo "Self-build: OK"
sudo podman rmi test-build
```

## Build Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU cores | 4 | 8+ |
| RAM | 8 GB | 16+ GB |
| Disk (builder) | 100 GB | 250 GB |
| Network | Required (pulls base image + packages) | Fast connection for RPM downloads |

The build process downloads ~2-4 GB of RPM packages from Fedora repos, RPM Fusion, Terra, and CrowdSec. Subsequent builds with dnf5 cache mounts are 5-10x faster.
