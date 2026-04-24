# 🔬 Codebase Audit & Research Plan — Universal Paravirtualization & Agnosticism (April 2026)

## 1. Executive Summary
Following the mandate that CloudWS-OS is **hardware, deployment, and environment agnostic**, a new research phase is required to identify missing upstream patches, user-space components, and configuration gaps that prevent native-like hardware acceleration across all supported environments (Bare-metal, VM, OCI, WSL2/g, Hyper-V).

## 2. Identified Gaps & Missing Components (April 2026 Audit)

### 2.1 Hyper-V / WSL2 GPU-PV & DDA
- **Research:** `dxgkrnl` (Microsoft) is NOT in Fedora Rawhide kernel (v4 patch iteration on LKML). DKMS/custom builds still required for non-WSL2 Hyper-V guests. `mesa-d3d12` (Dozen) is available in Fedora Mesa packages.
- **Status:** **Research Completed.**

### 2.2 Wayland Native RDP over VSOCK
- **Research:** `gnome-remote-desktop` (GRD) does not natively support `AF_VSOCK`. Proxy solutions (`socat`) are fragile and complex for bootc/immutable.
- **Status:** **Deferred.** Waiting for upstream GRD support.

### 2.3 SR-IOV Persistence in Immutable OS
- **Research:** Standard pattern is `systemd.link` or `systemd` oneshot. Oneshot is chosen for maximum driver compatibility on early boot.
- **Status:** **Implementation Pending.** (See Phase 2)

### 2.4 Universal CDI (Container Device Interface)
- **Research:** Podman requires vendor-specific generators (`nvidia-ctk`, `amd-ctk`, `intel-cdi-generator`).
- **Status:** **Implementation Pending.** (See Phase 3)

## 3. Implementation Tracking (v0.1.9)

| Task | Status | Note |
| :--- | :--- | :--- |
| **SR-IOV Oneshot** | In Progress | Replacing udev rule with `cloudws-sriov-init.service` |
| **Universal CDI** | In Progress | Adding AMD/Intel generators to `cloudws-cdi-detect` |
| **VSOCK RDP** | Deferred | Upstream dependency (GRD) |
| **dxgkrnl DKMS** | Backlog | Community-only, needs custom akmod/DKMS work |
