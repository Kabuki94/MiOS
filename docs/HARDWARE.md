# CloudWS-OS Hardware & Environment Compatibility Matrix (v2.4.0)

CloudWS-OS is **Hardware, Deployment, and Environment Agnostic** by design. It provides a universal, immutable workstation experience across all platforms, from bare-metal workstations to nested containers and virtual machines.

## Platform & Deployment Agnosticism

CloudWS-OS supports deployment in any modern environment with full hardware acceleration and para-virtualization.

| Platform | Deployment Method | Acceleration | Status |
|----------|-------------------|--------------|--------|
| **Bare Metal** | Anaconda ISO, RAW Disk, LVM | Native (Direct) | Primary |
| **Virtual Machine** | Hyper-V, QEMU/KVM, VMware, Proxmox | GPU-PV, SR-IOV, DDA/DDS, vsock | Full Support |
| **WSL2 / WSLg** | Tarball Import (.tar.gz) | D3D12 / GPU-PV | Full Support |
| **OCI Container** | Podman, Docker, Kubernetes | CDI, Device Passthrough | Full Support |
| **Live Media** | USB/ISO Live Image | Native (Memory-resident) | Full Support |

## Universal Vendor Support

CloudWS-OS provides out-of-the-box support for all major hardware vendors, leveraging both open-source and proprietary drivers as needed for a "zero-config" experience.

### GPU Support (Universal)

| Vendor | Generation | Driver Model | Acceleration |
|--------|------------|--------------|--------------|
| **NVIDIA** | Blackwell (RTX 50), Ada (RTX 40), Ampere (RTX 30), Turing (RTX 20) | Open & Proprietary | CDI, NVDEC/ENC, Vulkan, CUDA |
| **AMD** | RDNA 3, RDNA 2, RDNA 1, Vega, Polaris | `amdgpu` (Mesa) | ROCm, VA-API, Vulkan |
| **Intel** | Arc (Alchemist), Xe-HPG, Xe-LP, UHD | `xe` / `i915` (Mesa) | QuickSync, NEO OpenCL, Vulkan |
| **Apple** | Apple Silicon (M1/M2/M3/M4) | `Asahi` (Mesa) | Unified Memory (experimental/paravirt) |
| **ARM** | Mali, Adreno, Neoverse | `panfrost` / `freedreno` | Native GLES/Vulkan |

### CPU Support (Agnostic)

| Architecture | Features Supported |
|--------------|-------------------|
| **AMD x86_64** | Ryzen X3D (V-Cache Mapping), Threadripper (NUMA), Zen 2/3/4/5 |
| **Intel x86_64** | Core Hybrid (P/E-core Management), Xeon (Scalable/AVX-512), 8th-15th Gen |
| **ARM64** | Neoverse, Cortex, Apple Silicon (Virtualization extensions) |

## Para-virtualization & Hardware Shielding

To maintain its environment-agnostic nature, CloudWS-OS implements advanced para-virtualization and hardware isolation techniques:

- **GPU-PV / DDA**: Standardized GPU para-virtualization for Hyper-V and WSL2.
- **SR-IOV**: Native hardware partitioning for network and storage controllers.
- **VFIO-PCI**: Production-grade hardware passthrough for isolated device access in VMs.
- **VSOCK RDP**: Wayland-native RDP (gnome-remote-desktop) over VSOCK for high-performance remote access without network overhead.
- **CDI (Container Device Interface)**: Universal device injection for OCI containers (Podman/Docker).

## Environment Gating (Systemd)

CloudWS-OS uses systemd-native detection to adapt its services to the running environment:

- `ConditionVirtualization=!container`: Gated hardware services that don't apply to OCI.
- `ConditionVirtualization=!wsl`: Optimized gating for WSL2 interop.
- `ConditionPathExists=/dev/dri/renderD128`: Hardware-triggered service activation.

## Verification Tools

```bash
# General hardware check
cloudws-gpu-detect

# Environment & Virtualization audit
systemd-detect-virt

# Performance & Isolation profile
cloudws-assess
```
