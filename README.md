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
Technical specifications, filesystem hierarchy, and kernel optimizations.

### 🛠️ [Operational Handbook](docs/operations.md)
Deployment guides (WSL2, Hyper-V), backup strategies, and upgrade cycles.

### 🔒 [Security Ledger](docs/security.md)
Execution whitelisting, cryptographic integrity (fs-verity), and network hardening.

### 🔌 [Infrastructure Ledger](docs/infrastructure.md)
GPU-PV, SR-IOV, VFIO, and Silicon Vendor support matrices.

### 🧪 [Testing Protocol](docs/testing.md)
Automated validation suites (tmt) and SBOM provenance.

### 📋 [Feature Manifest](docs/manifest.md)
A structured index of all system components and capabilities.

---

## 🛠️ Quick Start

```bash
# Build the entire stack (RAW, VHDX, ISO, WSL)
just all

# Run localized system tests
just test
```

---
