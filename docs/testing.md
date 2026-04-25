# 🧪 CloudWS-OS Testing Protocol

```json
{
  "framework": "tmt (Test Management Tool)",
  "infrastructure": "Testing Farm / virtual.testcloud",
  "methodology": "Ephemeral OCI Validation"
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
| **IOMMU Audit** | Verify valid group isolation | `cloudws-vfio-check` |
| **KVMFR Hook** | Shared memory allocation check | `/dev/shm/looking-glass` |
| **GDM Readiness** | Wayland compositor boot success | `graphical.target` |

---

## 📋 Software Bill of Materials (SBOM)

CloudWS-OS generates cryptographically signed manifests for every build.

1. **Formats:** `CycloneDX`, `SPDX`.
2. **Provenance:** Built via GitHub Actions with OIDC identity verification.
3. **Storage:** Artifacts attached to GHCR image metadata.

---
