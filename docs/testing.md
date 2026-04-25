# 🌐 MiOS — Universal AI Integration
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🧪 MiOS-OS System Validation

```json
{
  "tools": "tmt (Test Management Tool)",
  "infrastructure": "Testing Farm / virtual.testcloud",
  "method": "Ephemeral OCI Validation"
}
```

---

## 🛠️ Validation Suites

### 🩺 Smoke Testing
Basic system integrity and service readiness checks.

```json
{
  "plan": "tests/tmt/plans/smoke.fmf",
  "checks": [
    "fs-verity-integrity",
    "systemd-initialization",
    "network-bridge-readiness"
  ]
}
```

### 🎮 Virtualization Stabiliy
Verifying the integrity of the KVM/VFIO stack.

| Test | Objective | Target |
| :--- | :--- | :--- |
| **IOMMU Audit** | Verify valid group isolation | `mios-vfio-check` |
| **KVMFR Hook** | Shared memory allocation check | `/dev/shm/looking-glass` |
| **GDM Readiness** | Wayland compositor boot success | `graphical.target` |

---

## 📋 Software Bill of Materials (SBOM)

MiOS-OS generates signed manifests for every build.

1. **Formats:** `CycloneDX`, `SPDX`.
2. **Records:** Built via GitHub Actions with OIDC identity verification.
3. **Storage:** Artifacts attached to GHCR image metadata.

---

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/MiOS](https://github.com/Kabuki94/MiOS)
- **Sole Proprietor:** Kabu.ki
---
