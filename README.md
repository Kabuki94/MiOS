# 🌐 CloudWS-bootc — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🌐 CloudWS-OS: Immutable Cloud-Native Workstation

```json
{
  "status": "Production Stable",
  "baseline": "v1.3.0",
  "kernel": "Fedora Rawhide (OCI-Mode)",
  "build": "just all"
}
```

---

## 🚀 Overview
CloudWS-OS is a container-native, mathematically verifiable workstation operating system. Built for high-performance virtualization (VFIO), hardware agnosticism, and zero-trust security, it transforms the host OS into a cryptographically sealed OCI payload.

### 🛡️ Core Mandates
- **Naked Core:** Minimalist base OS; applications reside in sandboxes (Flatpak/Distrobox).
- **Atomic Reliability:** Transactional image swaps with autonomous rollbacks.
- **Hardware Agnostic:** Optimized drivers for Intel, AMD, and NVIDIA.

---

## 🏗️ Documentation Hub

### 📐 [Strategic Blueprint](docs/blueprint.md)
Technical specs, filesystem hierarchy, and kernel tuning.

### 🛠️ [Operational Handbook](docs/operations.md)
Setup guides (WSL2, Hyper-V), backup steps, and upgrade cycles.

### 🔒 [Security Guide](docs/security.md)
Execution whitelisting, integrity checks (fs-verity), and network rules.

### 🔌 [Hardware Support](docs/infrastructure.md)
GPU-PV, SR-IOV, VFIO, and Silicon vendor details.

### 🧪 [System Validation](docs/testing.md)
Automated tests (tmt) and build manifests.

### 📋 [Feature Index](docs/manifest.md)
A structured list of all system components and features.

---

## 🛠️ Quick Start

```bash
# Build the entire stack (RAW, VHDX, ISO, WSL)
just all

# Run localized system tests
just test
```

---

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/CloudWS-bootc](https://github.com/Kabuki94/CloudWS-bootc)
- **Sole Proprietor:** Kabu.ki
---
