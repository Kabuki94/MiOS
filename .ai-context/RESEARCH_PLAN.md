# 🔬 Codebase Audit & Research Plan — Universal Paravirtualization & Agnosticism (April 2026)

## 1. Executive Summary
Following the mandate that CloudWS-OS is **hardware, deployment, and environment agnostic**, a new research phase is required to identify missing upstream patches, user-space components, and configuration gaps that prevent native-like hardware acceleration across all supported environments (Bare-metal, VM, OCI, WSL2/g, Hyper-V).

## 2. Identified Gaps & Missing Components

### 2.1 Hyper-V / WSL2 GPU-PV & DDA
- **Gap:** WSL2 and Hyper-V Enhanced Session rely on GPU Paravirtualization (GPU-PV) via Microsoft's `dxgkrnl` and Mesa's D3D12 (Dozen) driver.
- **Action:** Verify if `mesa-dri-drivers` and `mesa-vulkan-drivers` in Fedora 44/Rawhide include the `d3d12` Gallium driver.
- **Action:** Check if `dxgkrnl` module is included in the Fedora kernel or if a custom DKMS/akmod is required for non-WSL2 Hyper-V Linux guests to use GPU-PV.

### 2.2 Wayland Native RDP over VSOCK
- **Gap:** Legacy xRDP supported `AF_VSOCK` for Hyper-V Enhanced Session. We transitioned to `gnome-remote-desktop` (GRD) for GNOME 50 (Wayland-only).
- **Action:** Research if `gnome-remote-desktop` supports listening on `AF_VSOCK` out-of-the-box, or if a proxy (e.g., `socat` vsock-to-tcp) or upstream patch is required.

### 2.3 SR-IOV Persistence in Immutable OS
- **Gap:** SR-IOV Virtual Functions (VFs) are typically created by echoing numbers into `/sys/class/net/eth0/device/sriov_numvfs`. In an immutable/stateless boot environment, this needs declarative persistence.
- **Action:** Research the standard `systemd-networkd` or `udev` pattern for SR-IOV VF initialization on bootc systems.

### 2.4 Universal CDI (Container Device Interface)
- **Gap:** We have robust CDI generation for NVIDIA (`cloudws-cdi-detect.service`), but CDI should also map AMD (`/dev/kfd`, `/dev/dri`), Intel, and WSL2 (`/dev/dxg`) for universal container passthrough.
- **Action:** Implement a universal CDI generator or verify if `nvidia-container-toolkit` handles non-NVIDIA devices, or if `oci-device-hook` / podman native device passing is sufficient for open-source drivers.

## 3. Research Execution

### Phase 1: Upstream Patch Discovery
- Search for GNOME 50 `gnome-remote-desktop` VSOCK support.
- Search for Linux 6.14+ `dxgkrnl` upstream status for Hyper-V Linux guests.
- Search for bootc/systemd patterns for SR-IOV.

### Phase 2: Implementation
- Edit `docs/PACKAGES.md` to include missing paravirt packages (`socat`, `mesa-d3d12`, etc.).
- Create/update `system_files/` units for VSOCK proxying and SR-IOV initialization.
- Update CDI generation script for universal GPU mapping.
