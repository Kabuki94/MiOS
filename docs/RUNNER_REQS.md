# CloudWS CI Runner Hardware Requirements

## Builder Runner (Primary)

- **CPU**: 8–16 cores (matches `--build-arg MAKEFLAGS="-j$(nproc)"`)
- **RAM**: 128–256 GB (ROCm + Wine + full GNOME install peaks at ~80 GB during build)
- **Disk**: 1–2 TB NVMe (container storage + BIB artifacts; SSD minimum)
- **KVM**: /dev/kvm must be accessible
- **OS**: Fedora Server (latest stable) recommended for Rawhide compatibility
- **Podman**: Rootful mode, storage driver overlay

## Test Runner (Ephemeral Boots)

- **CPU**: 4–8 cores
- **RAM**: 32–64 GB
- **Disk**: 500 GB (QCOW2 artifacts are 15–30 GB each)
- **KVM**: Required for QEMU -enable-kvm
- **Timeout**: 5 minutes per boot test

## GPU Runner (Optional — Driver Matrix)

- **GPU**: NVIDIA RTX 4090 or similar (match target hardware)
- **RAM**: 128+ GB
- **CUDA**: Toolkit installed on host
- **Disk**: 1 TB+

## Signing Host (Recommended)

- **CPU/RAM**: Minimal (4 vCPU, 16 GB)
- **Security**: Isolated network segment, HSM/TPM for key storage
- **Software**: cosign, sbctl, mokutil

## Artifact Storage

- **Short-term**: GitHub Actions artifacts (7-day retention)
- **Long-term**: S3/MinIO with lifecycle policy
- **Estimate**: 100–500 GB per build (qcow2 + iso + raw + VHDX)