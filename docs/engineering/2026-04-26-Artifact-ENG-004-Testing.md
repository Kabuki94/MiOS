# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
> **Source Reference:** MiOS-Core-v2.1.0
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
### ⚖️ Legal & Source Reference
- **Copyright:** (c) 2026 Kabu.ki
- **Status:** Personal Property / Private Infrastructure
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Documentation:** [MiOS Navigation Hub](https://github.com/Kabuki94/mios/blob/main/docs/Home.md)
- **Artifact Hub:** [ai-context.json](https://github.com/Kabuki94/mios/blob/main/ai-context.json)
---