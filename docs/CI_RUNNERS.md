# CloudWS CI Runner Setup

## Architecture

CloudWS CI uses two tiers of runners:

- **GitHub-hosted** (ubuntu-latest): PR lint — shellcheck, hadolint, TOML validation
- **Self-hosted** (privileged Linux): Full image build, BIB artifact generation, ephemeral boot tests

Self-hosted runners are the authoritative build platform. No image is published
without passing a self-hosted build + boot test.

## Runner Labels

| Label | Role | Required Capabilities |
|-------|------|----------------------|
| `self-hosted, linux, privileged, builder` | Image builds, BIB | Podman rootful, /dev/kvm, 128+ GB RAM, 1 TB NVMe |
| `self-hosted, linux, privileged, qemu` | Ephemeral boot tests | QEMU-KVM, 64+ GB RAM, 500 GB disk |
| `self-hosted, linux, gpu, nvidia` | Driver matrix builds | NVIDIA GPU + drivers, CUDA toolkit |
| `self-hosted, linux, signer` | Image/module signing | cosign, sbctl, HSM/TPM recommended |

## Provisioning a Builder Runner

```bash
# Fedora Server recommended (closest to Rawhide build target)
sudo dnf install -y podman buildah skopeo qemu-kvm qemu-img libvirt

# Register with GitHub Actions
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64-2.321.0.tar.gz
tar xzf ./actions-runner.tar.gz
./config.sh --url https://github.com/Kabuki94/CloudWS-bootc --token YOUR_TOKEN
./svc.sh install && ./svc.sh start
```

## Nightly Rawhide Matrix

The `build-test.yml` workflow runs on a cron schedule (03:00 UTC daily).
This catches Rawhide regressions before they reach manual builds.
Failed nightly builds create a GitHub Issue automatically via the issue-on-failure action.

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `GHCR_TOKEN` | Push images to ghcr.io |
| `COSIGN_KEY` | Image signing (or use keyless OIDC) |