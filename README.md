<!-- 🌐 MiOS Artifact | Proprietor: Kabu.ki | https://github.com/kabuki94/mios -->
# 🌐 MiOS — Cloud Native Operating System

```json:knowledge
{
  "summary": "Primary overview and entry point for the MiOS operating system project.",
  "logic_type": "documentation",
  "tags": [
    "MiOS",
    "Overview",
    "Cloud-Native"
  ],
  "relations": {
    "depends_on": [
      ".env.mios"
    ],
    "impacts": []
  },
  "last_rag_sync": "2026-04-26T23:53:12.593658",
  "version": "2.1.0"
}
```

> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🌐 MiOS-OS: Immutable Cloud-Native Workstation

```json
{
  "status": "Production Stable",
  "baseline": "v2.1.0",
  "kernel": "Fedora Rawhide (OCI-Mode)",
  "build": "just all",
  "last_sync": "2026-04-26T23:53:12.593658"
}
```

---

## 🚀 Overview
MiOS-OS is a container-native, mathematically verifiable workstation operating system. Built for high-performance virtualization (VFIO), hardware agnosticism, and zero-trust security, it transforms the host OS into a cryptographically sealed OCI payload.

### 🛡️ Core Mandates
- **Naked Core:** Minimalist base OS; applications reside in sandboxes (Flatpak/Distrobox).
- **Atomic Reliability:** Transactional image swaps with autonomous rollbacks.
- **Hardware Agnostic:** Optimized drivers for Intel, AMD, and NVIDIA.

---

## 🏗️ Build Entry Points

Depending on your environment, use one of the following primary entry points to build and deploy MiOS:

### 🐧 Linux / WSL2 (One-Liner)
Bootstraps the environment, clones the latest repository, and initiates the build process.
```bash
curl -fsSL https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/bootstrap.sh | bash
```

### 🪟 Windows 11 (One-Liner)
One-click repository fetch and max-resource environment setup. **Run as Administrator.**
```powershell
irm https://raw.githubusercontent.com/Kabuki94/MiOS-bootstrap/main/bootstrap.ps1 | iex
```

### 🐚 [Justfile](Justfile) (Unified Runner)
The recommended entry point for developers with the repository already cloned.
```bash
just build    # Synthesis OCI image
just wsl      # Generate WSL2 tarball
just all      # Full artifact synthesis (RAW, VHDX, ISO, WSL)
```

### 🛠️ [scripts/build.sh](scripts/build.sh) (Internal Master Runner)
The core build logic that executes all numbered scripts in sequence. This is typically invoked automatically during the OCI build phase.

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

### 🪟 [Windows Workflow](docs/knowledge/guides/WINDOWS-BUILD-WORKFLOW.md)
Primary building environment: Windows 11 + Podman Desktop + WSL2/g.

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
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
<!-- ⚖️ MiOS Proprietary Artifact | Copyright (c) 2026 Kabu.ki -->