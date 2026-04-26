# 🌐 MiOS — Cloud Native Operating System
> **Proprietor:** Kabu.ki
> **Infrastructure:** Self-Building Infrastructure (Personal Property)
> **License:** Licensed as personal property to Kabu.ki
---
# 🛡️ MiOS-OS Security Guide

```json
{
  "setup": "Zero-Trust Enforcement",
  "frameworks": ["fapolicyd", "USBGuard", "CrowdSec", "fs-verity"],
  "standard": "Immutable OCI"
}
```

---

## 🔒 Hardened Layers

### 🧠 Execution Control
MiOS-OS implements strict binary whitelisting to prevent unauthorized execution.

```json
{
  "whitelisting": {
    "engine": "fapolicyd",
    "policy": "deny-by-default",
    "exceptions": ["/usr/bin", "/usr/lib", "/usr/local/bin"]
  }
}
```

### ⚡ Cryptographic Integrity
The core system is sealed using `composefs` and the Linux kernel's `fs-verity` subsystem.

1. **Seal:** Root partition is hashed during build.
2. **Audit:** `mios-verify` checks signatures early in the initramfs boot phase.
3. **Recovery:** Immediate autonomous rollback to fallback deployment on verification failure.

---

## 🔌 Physical Security

### ⌨️ Peripheral Gating
USBGuard intercepts unauthorized devices at the kernel level.

| Device Type | Policy | Implementation |
| :--- | :--- | :--- |
| **Connected at Boot** | `Allow` | Implicit trust of pre-existing hardware |
| **New Inseration** | `Block` | Requires `usbguard allow-device` |
| **HID Emulators** | `Deny` | Instant detection and lockout |

---

## 🌐 Network Defense
Firewalld is configured for maximum isolation.

```json
{
  "firewall": {
    "default_zone": "drop",
    "active_ips": "CrowdSec sovereign engine",
    "whitelisted_interfaces": ["lo", "podman0", "virbr0"]
  }
}
```

---

## 🛠️ Infrastructure Hardening

### 🧠 Kernel Hardening
MiOS-OS implements the **SecureBlue 29-parameter kernel hardening** standard.

| Parameter | Rationale |
| :--- | :--- |
| `slab_nomerge` | Prevents heap layout manipulation. |
| `init_on_alloc=1` | Zeroes memory on allocation. |
| `init_on_free=1` | Zeroes memory on free. |
| `page_alloc.shuffle=1` | Randomizes page allocator freelists. |
| `randomize_kstack_offset=on` | Randomizes kernel stack offsets per syscall. |
| `lockdown=integrity` | Protects kernel integrity while allowing MOK-signed kmods. |
| `debugfs=off` | Disables debugfs to prevent information leaks. |
| `oops=panic` | Prevents system exploitation after a kernel oops. |
| `iommu=force` | Forces hardware-level DMA isolation. |

---

---
### 📚 Bootc Ecosystem & Resources
- **Core:** [containers/bootc](https://github.com/containers/bootc) | [bootc-image-builder](https://github.com/osbuild/bootc-image-builder) | [bootc.pages.dev](https://bootc.pages.dev/)
- **Upstream:** [Fedora Bootc](https://github.com/fedora-cloud/fedora-bootc) | [CentOS Bootc](https://gitlab.com/CentOS/bootc) | [ublue-os/main](https://github.com/ublue-os/main)
- **Tools:** [uupd](https://github.com/ublue-os/uupd) | [rechunk](https://github.com/hhd-dev/rechunk) | [cosign](https://github.com/sigstore/cosign)
- **Project Repository:** [Kabuki94/mios](https://github.com/Kabuki94/mios)
- **Sole Proprietor:** Kabu.ki
---
