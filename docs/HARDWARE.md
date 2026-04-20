# Hardware Compatibility Matrix (v0.1.8)

CloudWS-bootc includes GPU auto-detection at boot that adapts the driver configuration for bare metal, Hyper-V, QEMU, or VMware environments. This document lists supported hardware, required firmware, and known incompatibilities.

## GPU Support

### AMD GPUs

| Generation | Example Models | Driver | Status |
|------------|---------------|--------|--------|
| RDNA 3 | RX 7900 XTX, RX 7800 XT, RX 7600 | `amdgpu` (Mesa) | Fully supported |
| RDNA 2 | RX 6900 XT, RX 6700 XT, RX 6600 | `amdgpu` (Mesa) | Fully supported |
| Polaris / Vega | RX 580, Vega 64 | `amdgpu` (Mesa) | Supported |

### Intel GPUs

| Generation | Example Models | Driver | Status |
|------------|---------------|--------|--------|
| Arc (Alchemist) | A770, A750 | `xe` / `i915` | Supported (kernel 6.8+) |
| Xe-LP (Gen12) | Iris Xe | `i915` (Mesa) | Fully supported |

### NVIDIA GPUs

| Generation | Example Models | Driver | Kernel Module | Status |
|------------|---------------|--------|---------------|--------|
| Blackwell (RTX 50xx) | RTX 5090, RTX 5080 | 595+ | Open ONLY | Supported (Safety Workaround active) |
| Ada Lovelace (RTX 40xx) | RTX 4090, RTX 4080 | 595+ | Open (default) | Fully supported |
| Ampere (RTX 30xx) | RTX 3090, RTX 3080 | 595+ | Open (default) | Fully supported |
| Turing (RTX 20xx) | RTX 2080 Ti, RTX 2070 | 595+ | Open (default) | Fully supported |

**NVIDIA 595+ Stability:** CloudWS includes a mandatory stability workaround for NVIDIA 595.x drivers. `NVreg_UseKernelSuspendNotifiers=1` is injected into the module configuration to resolve suspend/resume freezes on Wayland.

**Blackwell (RTX 50) Support:** RTX 50-series hardware requires the `vfio_pci.disable_idle_d3=1` kernel argument for stable operation. This is automatically applied in `00-cloudws.toml`. On first boot, the system may default to **Headless** mode as a hardware safety precaution.

**WSL 2.7.0 Compatibility:** Discovered a network-wait hang in WSL 2.7.0. CloudWS automatically gates `systemd-networkd-wait-online.service` on `!wsl` to prevent login timeouts.

## Platform Support

| Platform | Format | Status | Notes |
|----------|--------|--------|-------|
| Bare metal | Anaconda ISO, RAW disk | Fully supported | Primary target |
| Hyper-V Gen2 | VHDX | Fully supported | Enhanced Session via GRD over vsock:3389 |
| WSL2 | Tarball import | Supported | Fixed user session permissions (WSL 2.6.0.0 fix) |
| QEMU/KVM | RAW disk, OCI | Fully supported | Nested virt for testing |

## Firmware Requirements

- **UEFI**: Required (no legacy BIOS support)
- **Secure Boot**: Supported — NVIDIA modules signed with Universal Blue MOK keys
- **TPM 2.0**: Optional — used for LUKS+TPM2 binding
