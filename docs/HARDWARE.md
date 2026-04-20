# Hardware Compatibility Matrix

CloudWS-bootc includes GPU auto-detection at boot that adapts the driver configuration for bare metal, Hyper-V, QEMU, or VMware environments. This document lists supported hardware, required firmware, and known incompatibilities.

## GPU Support

### AMD GPUs

| Generation | Example Models | Driver | Status |
|------------|---------------|--------|--------|
| RDNA 3 | RX 7900 XTX, RX 7800 XT, RX 7600 | `amdgpu` (Mesa) | Fully supported |
| RDNA 2 | RX 6900 XT, RX 6700 XT, RX 6600 | `amdgpu` (Mesa) | Fully supported |
| RDNA 1 | RX 5700 XT, RX 5600 XT | `amdgpu` (Mesa) | Fully supported |
| Vega | Vega 56, Vega 64, VII | `amdgpu` (Mesa) | Fully supported |
| Polaris | RX 580, RX 570, RX 480 | `amdgpu` (Mesa) | Supported |
| GCN 1-3 | R9 390, R9 290, R9 280 | `amdgpu`/`radeon` | Legacy — limited |

AMD compute (ROCm OpenCL/HIP) is installed as an optional, fault-tolerant package. ROCm officially supports RDNA 2+ and CDNA architectures.

### Intel GPUs

| Generation | Example Models | Driver | Status |
|------------|---------------|--------|--------|
| Arc (Alchemist) | A770, A750, A380 | `xe` / `i915` (Mesa) | Supported (kernel 6.8+) |
| Xe-HPG (DG2) | Arc A-series | `xe` (Mesa) | Supported |
| Xe-LP (Gen12) | Iris Xe (11th-14th gen iGPU) | `i915` (Mesa) | Fully supported |
| Gen9-11 | UHD 630, Iris Plus | `i915` (Mesa) | Fully supported |

Intel GPUs use the Mesa Vulkan (ANV) and OpenGL (Iris) drivers. No additional packages are required beyond `mesa-vulkan-drivers` and `mesa-dri-drivers`.

### NVIDIA GPUs

| Generation | Example Models | Driver | Kernel Module | Status |
|------------|---------------|--------|---------------|--------|
| Blackwell (RTX 50xx) | RTX 5090, RTX 5080, RTX 5070 | 590+ | Open ONLY | Supported — proprietary modules incompatible |
| Ada Lovelace (RTX 40xx) | RTX 4090, RTX 4080, RTX 4070 | 590+ | Open (default) | Fully supported |
| Ampere (RTX 30xx) | RTX 3090, RTX 3080, RTX 3070 | 590+ | Open (default) | Fully supported |
| Turing (RTX 20xx) | RTX 2080 Ti, RTX 2070, RTX 2060 | 590+ | Open (default) | Fully supported |
| Pascal (GTX 10xx) | GTX 1080 Ti, GTX 1070, GTX 1060 | — | — | NOT SUPPORTED (driver 590 dropped Pascal) |
| Maxwell, Kepler, older | GTX 980, GTX 750 Ti | — | — | NOT SUPPORTED |

NVIDIA drivers are delivered via:
- **CloudWS-1** (Fedora Rawhide base): `akmod-nvidia` from RPM Fusion, built at image time
- **CloudWS-2** (ucore-hci base): Pre-signed NVIDIA modules from Universal Blue, signed with ublue MOK for Secure Boot

CDI (Container Device Interface) is the default mode for GPU access in Podman containers (`podman run --device nvidia.com/gpu=0`).

**Known issues:**
- RTX 50-series has a VFIO reset bug affecting GPU passthrough — CloudWS detects this at boot and displays a warning
- NVIDIA driver 590 from RPM Fusion may break for 1-2 days after upstream updates — the weekly CI rebuild mitigates this
- `nvidia-container-toolkit` must be ≥ v1.17.7 (CVE-2025-23266 Critical, CVE-2025-23267 High)

### GPU Passthrough (VFIO)

Any GPU supported above can be passed through to a virtual machine via VFIO, with these requirements:

- **BIOS/UEFI**: IOMMU must be enabled (VT-d for Intel, AMD-Vi for AMD)
- **IOMMU groups**: The GPU must be in its own IOMMU group (or use ACS override)
- **Two GPUs**: You need a host GPU (typically integrated) and a passthrough GPU
- **CloudWS tools**: Use `cloudws-vfio-check` to validate readiness, `cloudws-gpu-toggle` to switch between host and VFIO drivers

## CPU Support

| Vendor | Minimum | Recommended | Notes |
|--------|---------|-------------|-------|
| AMD | Zen 2 (Ryzen 3000) | Zen 4+ (Ryzen 7000+) | AMD-Vi for VFIO, SEV-SNP on EPYC |
| Intel | 8th Gen (Coffee Lake) | 12th Gen+ (Alder Lake+) | VT-d + VT-x for VFIO |

Minimum requirements: x86_64 CPU with virtualization extensions (VT-x/AMD-V). IOMMU (VT-d/AMD-Vi) required for GPU passthrough.

## Platform Support

| Platform | Format | Status | Notes |
|----------|--------|--------|-------|
| Bare metal | Anaconda ISO, RAW disk | Fully supported | Primary target |
| Hyper-V Gen2 | VHDX | Fully supported | Enhanced Session via gnome-remote-desktop over vsock:3389 (GNOME 50 / Mutter 50 is Wayland-only — xorgxrdp no longer works; xrdp stays installed as a fallback for non-GNOME sessions) |
| WSL2 | Tarball import | Supported | GPU via WSLg/D3D12, no VFIO |
| QEMU/KVM | RAW disk, OCI | Fully supported | Nested virt for testing |
| VMware | OCI pull | Basic support | Open VM Tools included |

## Firmware Requirements

- **UEFI**: Required (no legacy BIOS support)
- **Secure Boot**: Supported — NVIDIA modules signed with Fedora or ublue MOK keys
- **TPM 2.0**: Optional — used for LUKS+TPM2 binding (`bootc install to-disk --block-setup tpm2-luks`)

## Network Hardware

NetworkManager handles all network configuration. Wi-Fi support requires `NetworkManager-wifi` (included in PACKAGES.md).

| Type | Support |
|------|---------|
| Ethernet (Intel, Realtek, Broadcom) | Fully supported via `linux-firmware` |
| Wi-Fi (Intel AX200/210/411, Realtek, MediaTek) | Supported via `linux-firmware` |
| Wi-Fi (Broadcom) | May require `broadcom-wl` — not included by default |
| Bluetooth | Supported via `bluez` + `gnome-bluetooth` |

## Storage

| Type | Support |
|------|---------|
| NVMe | Fully supported |
| SATA/AHCI | Fully supported |
| NFS | Client and server included |
| iSCSI | Initiator and target included |
| Ceph | Client included, cephadm for cluster bootstrap |
| GlusterFS | Client and server included |
| ZFS | Not included (licensing) |
| Btrfs / XFS / ext4 | All supported |

## Verifying Hardware Detection

After booting CloudWS, verify your hardware is properly detected:

```bash
# GPU detection
cloudws-gpu-detect    # Shows detected GPUs and active drivers

# VFIO readiness
cloudws-vfio-check    # Validates IOMMU, modules, GPU isolation

# Full system profile
lspci -nnk            # All PCI devices with drivers
lsusb                 # USB devices
inxi -Fxxxz           # Comprehensive system summary (if installed)
```
